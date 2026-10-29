using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Controllers;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;
using Xunit;

public class ScreenTimeLimitsTests
{
    private static async Task<ApplicationDbContext> Database()
    {
        var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Devices.Add(new Device { Id = 1, ChildId = 1, DeviceName = "Test", DeviceIdentifier = "test" });
        db.ParentChildren.Add(new ParentChild { ParentId = "owner", ChildId = 1 });
        db.ScreenTimeLimits.Add(new ScreenTimeLimit { Id = 1, DeviceId = 1, DailyLimitMinutes = 120 });
        await db.SaveChangesAsync();
        return db;
    }

    private static ScreenTimeLimitsController Controller(ApplicationDbContext db, string? parent = "owner")
    {
        var claims = parent == null ? Array.Empty<Claim>() :
            new[] { new Claim(ClaimTypes.NameIdentifier, parent), new Claim(ClaimTypes.Role, "Parent") };
        return new ScreenTimeLimitsController(db) {
            ControllerContext = new ControllerContext {
                HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(claims, "test")) }
            }
        };
    }

    private static SetScreenTimeLimitDto Update(int minutes = 60, int device = 1) =>
        new() { DeviceId = device, LimitType = "TOTAL", DailyLimitMinutes = minutes };

    [Fact]
    public async Task OwnerUpdatesExistingRecordWithoutAddingAnother()
    {
        await using var db = await Database();
        Assert.IsType<OkObjectResult>(await Controller(db).UpdateLimit(1, Update()));
        Assert.Single(db.ScreenTimeLimits);
        Assert.Equal(60, (await db.ScreenTimeLimits.SingleAsync()).DailyLimitMinutes);
    }

    [Fact]
    public async Task AnotherParentCannotUpdateOrDelete()
    {
        await using var db = await Database();
        var controller = Controller(db, "other-family");
        Assert.IsType<ForbidResult>(await controller.UpdateLimit(1, Update()));
        Assert.IsType<ForbidResult>(await controller.DeleteLimit(1));
        Assert.Equal(120, (await db.ScreenTimeLimits.SingleAsync()).DailyLimitMinutes);
    }

    [Fact]
    public async Task CannotMoveLimitToAnotherDevice()
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Controller(db).UpdateLimit(1, Update(device: 2)));
        Assert.Equal(1, (await db.ScreenTimeLimits.SingleAsync()).DeviceId);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1441)]
    public async Task RejectsMinutesOutsideOneDay(int minutes)
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Controller(db).UpdateLimit(1, Update(minutes)));
    }

    [Fact]
    public async Task OwnerCanDeleteUnusedLimit()
    {
        await using var db = await Database();
        Assert.IsType<NoContentResult>(await Controller(db).DeleteLimit(1));
        Assert.Empty(db.ScreenTimeLimits);
    }

    [Fact]
    public async Task DeletionPreservesRequestHistory()
    {
        await using var db = await Database();
        db.TimeRequests.Add(new TimeRequest { ChildId = 1, DeviceId = 1, ScreenTimeLimitId = 1, RequestedMinutes = 10 });
        await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await Controller(db).DeleteLimit(1));
        Assert.Single(db.ScreenTimeLimits);
        Assert.Single(db.TimeRequests);
    }

    [Fact]
    public async Task MissingIdentityIsUnauthorized()
    {
        await using var db = await Database();
        Assert.IsType<UnauthorizedResult>(await Controller(db, null).DeleteLimit(1));
    }

    [Fact]
    public void BothMutationsRequireParentRole()
    {
        foreach (var method in new[] { "UpdateLimit", "DeleteLimit" })
        {
            var attributes = typeof(ScreenTimeLimitsController).GetMethod(method)!
                .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>();
            Assert.Contains(attributes, attribute => attribute.Roles == "Parent");
        }
    }
}
