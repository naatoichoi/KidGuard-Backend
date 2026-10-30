using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using phamngocanh.Controllers;
using phamngocanh.Data;
using phamngocanh.Models;
using Xunit;

public class ScreenTimeStatusTests
{
    private static ServiceProvider Services()
    {
        var services = new ServiceCollection().AddLogging();
        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseInMemoryDatabase(Guid.NewGuid().ToString()));
        services.AddIdentityCore<ApplicationUser>().AddEntityFrameworkStores<ApplicationDbContext>();
        return services.BuildServiceProvider();
    }

    private static async Task Seed(ApplicationDbContext db, string type, long seconds)
    {
        var day = DateTime.UtcNow.Date;
        db.Users.AddRange(new ApplicationUser { Id = "parent", UserName = "parent" },
            new ApplicationUser { Id = "child", UserName = "child" });
        db.Children.Add(new Child { Id = 1, UserId = "child", FullName = "Test child", OtpRecipientParentId = "parent" });
        db.ParentChildren.Add(new ParentChild { ParentId = "parent", ChildId = 1 });
        db.Devices.Add(new Device { Id = 1, ChildId = 1, DeviceName = "Test", DeviceIdentifier = "test" });
        db.ScreenTimeLimits.Add(new ScreenTimeLimit { Id = 1, DeviceId = 1, LimitType = type,
            PackageName = type == "APP" ? "com.example.video" : null, DailyLimitMinutes = 1 });
        db.AppUsages.Add(new AppUsage { DeviceId = 1, PackageName = "com.example.video",
            AppName = "Video", UsageDate = day, DurationSeconds = seconds });
        // Another app must not cause the APP rule to expire.
        db.AppUsages.Add(new AppUsage { DeviceId = 1, PackageName = "com.example.study",
            AppName = "Study", UsageDate = day, DurationSeconds = 600 });
        db.DailyScreenTimes.Add(new DailyScreenTime { DeviceId = 1, UsageDate = day, TotalSeconds = seconds });
        await db.SaveChangesAsync();
    }

    private static ScreenTimeController Controller(IServiceScope scope, string user = "parent", string role = "Parent")
    {
        var controller = new ScreenTimeController(scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(),
            scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>());
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity(new[] {
                new Claim(ClaimTypes.NameIdentifier, user), new Claim(ClaimTypes.Role, role)
            }, "test")) } };
        return controller;
    }

    private static JsonElement Payload(OkObjectResult result) => JsonSerializer.SerializeToElement(result.Value);

    [Theory]
    [InlineData("APP", 30, "NORMAL")]
    [InlineData("APP", 48, "WARNING")]
    [InlineData("APP", 60, "EXCEEDED")]
    [InlineData("APP", 90, "EXCEEDED")]
    [InlineData("TOTAL", 30, "NORMAL")]
    [InlineData("TOTAL", 48, "WARNING")]
    [InlineData("TOTAL", 60, "EXCEEDED")]
    public async Task StatusReflectsUsageAndExactExpiry(string type, long seconds, string expected)
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        await Seed(scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(), type, seconds);
        var result = Payload(Assert.IsType<OkObjectResult>(await Controller(scope).GetLimitStatus(1, null)));
        var limit = result.GetProperty("limits")[0];
        Assert.Equal(expected, limit.GetProperty("status").GetString());
        Assert.Equal(type, limit.GetProperty("limitType").GetString());
        if (expected == "EXCEEDED") Assert.Equal(0, limit.GetProperty("remainingMinutes").GetDouble());
    }

    [Fact]
    public async Task ApprovedTimeAppliesOnlyOnItsEffectiveDay()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await Seed(db, "APP", 60);
        db.TimeRequests.Add(new TimeRequest { Id = 1, ChildId = 1, DeviceId = 1,
            ScreenTimeLimitId = 1, RequestedMinutes = 2, Status = "APPROVED" });
        db.TimeExtensions.Add(new TimeExtension { TimeRequestId = 1, ScreenTimeLimitId = 1,
            ExtraMinutes = 2, EffectiveDate = DateTime.UtcNow.Date });
        db.TimeExtensions.Add(new TimeExtension { TimeRequestId = 1, ScreenTimeLimitId = 1,
            ExtraMinutes = 10, EffectiveDate = DateTime.UtcNow.Date.AddDays(-1) });
        await db.SaveChangesAsync();
        var result = Payload(Assert.IsType<OkObjectResult>(await Controller(scope, "child", "Child").GetLimitStatus(1, null)));
        var limit = result.GetProperty("limits")[0];
        Assert.Equal(2, limit.GetProperty("extraMinutes").GetInt32());
        Assert.Equal(2, limit.GetProperty("remainingMinutes").GetDouble());
        Assert.Equal("NORMAL", limit.GetProperty("status").GetString());
    }

    [Fact]
    public async Task UnrelatedParentCannotReadStatus()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        await Seed(scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(), "APP", 60);
        var denied = Assert.IsType<ObjectResult>(await Controller(scope, "other-parent").GetLimitStatus(1, null));
        Assert.Equal(403, denied.StatusCode);
    }
}
