using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using phamngocanh.Controllers;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;
using Xunit;

public class LocationAndAppsTests
{
    [Fact]
    public async Task EditingARealAppPreservesItsExactAndroidPackage()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        db.ScreenTimeLimits.Add(new ScreenTimeLimit { Id = 1, DeviceId = 1, LimitType = "APP", PackageName = "com.Example.Study", DailyLimitMinutes = 10 });
        await db.SaveChangesAsync();
        var controller = new ScreenTimeLimitsController(db); Identity(controller, "parent", "Parent");
        Assert.IsType<OkObjectResult>(await controller.UpdateLimit(1, new SetScreenTimeLimitDto {
            DeviceId = 1, LimitType = "APP", PackageName = "com.Example.Study", DailyLimitMinutes = 20
        }));
        Assert.Equal("com.Example.Study", (await db.ScreenTimeLimits.SingleAsync()).PackageName);
    }
    private static ServiceProvider Services()
    {
        var services = new ServiceCollection().AddLogging();
        services.AddDbContext<ApplicationDbContext>(options => options.UseInMemoryDatabase(Guid.NewGuid().ToString()));
        services.AddIdentityCore<ApplicationUser>().AddEntityFrameworkStores<ApplicationDbContext>();
        return services.BuildServiceProvider();
    }
    private static void Identity(ControllerBase controller, string user, string role) => controller.ControllerContext =
        new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(new[] {
            new Claim(ClaimTypes.NameIdentifier, user), new Claim(ClaimTypes.Role, role)
        }, "test")) }};
    private static async Task Seed(ApplicationDbContext db)
    {
        db.Users.AddRange(new ApplicationUser { Id = "parent", UserName = "parent" },
            new ApplicationUser { Id = "child", UserName = "child" });
        db.Children.Add(new Child { Id = 1, UserId = "child", FullName = "Bé An", OtpRecipientParentId = "parent" });
        db.ParentChildren.Add(new ParentChild { ParentId = "parent", ChildId = 1 });
        db.Devices.Add(new Device { Id = 1, ChildId = 1, DeviceName = "Pixel 7", DeviceIdentifier = "pixel" });
        await db.SaveChangesAsync();
    }
    private static SyncLocationDto Location(bool notify = true) => new() {
        DeviceId = 1, Latitude = 21.02867m, Longitude = 105.85215m, AccuracyMeters = 12,
        RecordedAt = DateTime.UtcNow, Source = "EMULATOR", Address = "Khu vực hồ Hoàn Kiếm, Hà Nội", NotifyParents = notify
    };
    private static JsonElement Json(OkObjectResult result) => JsonSerializer.SerializeToElement(result.Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));

    [Fact]
    public async Task ManualShareStoresAddressAndNotifiesOnlyLinkedParent()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var controller = new LocationsController(db, scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>());
        Identity(controller, "child", "Child");
        Assert.IsType<OkObjectResult>(await controller.SyncLocation(Location()));
        Assert.Equal("Khu vực hồ Hoàn Kiếm, Hà Nội", (await db.Locations.SingleAsync()).Address);
        var notification = await db.Notifications.SingleAsync();
        Assert.Equal("parent", notification.UserId);
        Assert.Equal("LOCATION_SHARED", notification.Type);
        Assert.Contains("Hoàn Kiếm", notification.Message);
        Identity(controller, "parent", "Parent");
        var latest = Json(Assert.IsType<OkObjectResult>(await controller.GetLatestLocation(1)));
        Assert.Contains("Hoàn Kiếm", latest.GetProperty("location").GetProperty("address").GetString());
    }

    [Fact]
    public async Task AutomaticShareDoesNotSpamNotifications()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var controller = new LocationsController(db, scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>());
        Identity(controller, "child", "Child");
        Assert.IsType<OkObjectResult>(await controller.SyncLocation(Location(false)));
        Assert.Single(db.Locations); Assert.Empty(db.Notifications);
    }

    [Fact]
    public async Task MissingAddressStillStoresCoordinatesAndUnrelatedParentCannotView()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var controller = new LocationsController(db, scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>());
        Identity(controller, "child", "Child");
        var dto = Location(); dto.Address = null;
        Assert.IsType<OkObjectResult>(await controller.SyncLocation(dto));
        Assert.Equal(21.02867m, (await db.Locations.SingleAsync()).Latitude);
        Assert.Contains("Tọa độ", (await db.Notifications.SingleAsync()).Message);
        Identity(controller, "other-parent", "Parent");
        Assert.IsType<ForbidResult>(await controller.GetLatestLocation(1));
    }

    [Fact]
    public async Task AppCatalogIncludesUnusedAppsAndChecksOwnership()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        db.AppUsages.Add(new AppUsage { DeviceId = 1, PackageName = "com.zing.zalo", AppName = "Zalo", UsageDate = DateTime.UtcNow.Date, DurationSeconds = 0 });
        await db.SaveChangesAsync();
        var controller = new DeviceAppsController(db); Identity(controller, "parent", "Parent");
        var app = Json(Assert.IsType<OkObjectResult>(await controller.GetApps(1))).GetProperty("apps")[0];
        Assert.Equal("Zalo", app.GetProperty("appName").GetString());
        Assert.Equal(0, app.GetProperty("durationSeconds").GetInt64());
        Identity(controller, "other-parent", "Parent");
        Assert.IsType<ForbidResult>(await controller.GetApps(1));
    }

    [Fact]
    public async Task YesterdayInventoryDoesNotPretendYesterdayUsageIsToday()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        db.AppUsages.Add(new AppUsage { DeviceId = 1, PackageName = "video", AppName = "Video", UsageDate = DateTime.UtcNow.Date.AddDays(-1), DurationSeconds = 600 });
        await db.SaveChangesAsync();
        var controller = new DeviceAppsController(db); Identity(controller, "parent", "Parent");
        var result = Json(Assert.IsType<OkObjectResult>(await controller.GetApps(1)));
        Assert.Equal(0, result.GetProperty("apps")[0].GetProperty("durationSeconds").GetInt64());
        Assert.NotEqual(result.GetProperty("usageDate").GetString(), result.GetProperty("inventoryDate").GetString());
    }

    [Fact]
    public async Task UnknownPackageIsRejectedButARealUnusedAppCanBeLimited()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var controller = new ScreenTimeLimitsController(db); Identity(controller, "parent", "Parent");
        var dto = new SetScreenTimeLimitDto { DeviceId = 1, LimitType = "APP", PackageName = "wrong.name", DailyLimitMinutes = 10 };
        Assert.IsType<BadRequestObjectResult>(await controller.SetLimit(dto));
        Assert.Empty(db.ScreenTimeLimits);
        db.AppUsages.Add(new AppUsage { DeviceId = 1, PackageName = "com.zing.zalo", AppName = "Zalo", UsageDate = DateTime.UtcNow.Date });
        await db.SaveChangesAsync(); dto.PackageName = "com.zing.zalo";
        Assert.IsType<OkObjectResult>(await controller.SetLimit(dto));
        Assert.Equal("com.zing.zalo", (await db.ScreenTimeLimits.SingleAsync()).PackageName);
    }
}
