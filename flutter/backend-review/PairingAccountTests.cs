using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using phamngocanh.Controllers;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;
using phamngocanh.Services;
using Xunit;

public class PairingAccountTests
{
    private const string Qr = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    private static ServiceProvider Services()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddDataProtection().UseEphemeralDataProtectionProvider();
        services.AddDbContext<ApplicationDbContext>(options => options
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        services.AddIdentityCore<ApplicationUser>(options => {
            options.Password.RequireDigit = true; options.Password.RequireLowercase = true;
            options.Password.RequireUppercase = false; options.Password.RequireNonAlphanumeric = false;
            options.Password.RequiredLength = 6;
        }).AddRoles<IdentityRole>().AddEntityFrameworkStores<ApplicationDbContext>().AddDefaultTokenProviders();
        services.AddSingleton<IConfiguration>(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
            ["Jwt:Key"] = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)),
            ["Jwt:Issuer"] = "test", ["Jwt:Audience"] = "test", ["Jwt:ExpireMinutes"] = "120"
        }).Build());
        services.AddScoped<JwtService>();
        return services.BuildServiceProvider();
    }
    private static void Identity(ControllerBase controller, string id, string role = "Parent") =>
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity(new[] {
                new Claim(ClaimTypes.NameIdentifier, id), new Claim(ClaimTypes.Role, role)
            }, "test"))
        }};

    private static async Task Seed(ApplicationDbContext db, DateTime? expiry = null)
    {
        db.Users.Add(new ApplicationUser { Id = "parent", UserName = "guardian", Email = "parent@example.test" });
        db.PairingCodes.Add(new PairingCode {
            SetupTokenHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Qr))),
            DeviceIdentifier = "test-phone", DeviceName = "Test Phone", DeviceSecretHash = "hash",
            ExpiresAt = expiry ?? DateTime.UtcNow.AddMinutes(5)
        });
        await db.SaveChangesAsync();
    }
    private static ConfirmPairingDto Account(string password = "child123") => new() {
        QrData = Qr, ChildName = "Bé An", UserName = "be_an", Password = password, ConfirmPassword = password
    };

    [Fact]
    public async Task OnlyLinkedParentCanSetLegacyChildCredentialsWithoutNewAccount()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var old = new ApplicationUser { UserName = "child_legacy", FullName = "Old" };
        Assert.True((await users.CreateAsync(old)).Succeeded);
        var child = new Child { UserId = old.Id, FullName = "Old", OtpRecipientParentId = "parent" };
        db.Children.Add(child); await db.SaveChangesAsync();
        db.ParentChildren.Add(new ParentChild { ParentId = "parent", ChildId = child.Id }); await db.SaveChangesAsync();
        var controller = new ChildSessionController(db, scope.ServiceProvider.GetRequiredService<JwtService>());
        var dto = new ChildAccountUpdateDto { ChildName = "Bé An", UserName = "be_an", Password = "new123", ConfirmPassword = "new123" };
        Identity(controller, "other-parent");
        Assert.IsType<ForbidResult>(await controller.UpdateAccount(child.Id, dto, users));
        Identity(controller, "parent");
        Assert.IsType<OkObjectResult>(await controller.UpdateAccount(child.Id, dto, users));
        Assert.Single(db.Children);
        Assert.True(await users.CheckPasswordAsync((await users.FindByNameAsync("be_an"))!, "new123"));
    }

    [Fact]
    public async Task ScanCreatesPersistentChildWithRealPasswordAndParentRecipient()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var controller = new PairingController(db, users, scope.ServiceProvider.GetRequiredService<JwtService>());
        Identity(controller, "parent");
        Assert.IsType<OkObjectResult>(await controller.Confirm(Account()));
        var child = await db.Children.SingleAsync();
        var user = (await users.FindByIdAsync(child.UserId))!;
        Assert.Equal("be_an", user.UserName);
        Assert.True(await users.CheckPasswordAsync(user, "child123"));
        Assert.True(await users.IsInRoleAsync(user, "Child"));
        Assert.Equal("parent", child.OtpRecipientParentId);
        Assert.Single(db.Devices);
        Assert.IsType<ConflictObjectResult>(await controller.Confirm(Account()));
        Assert.Single(db.Children);
    }

    [Fact]
    public async Task ExpiredQrDoesNotCreateAccount()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db, DateTime.UtcNow.AddSeconds(-1));
        var controller = new PairingController(db, scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>(),
            scope.ServiceProvider.GetRequiredService<JwtService>());
        Identity(controller, "parent");
        Assert.IsType<BadRequestObjectResult>(await controller.Confirm(Account()));
        Assert.Empty(db.Children); Assert.Empty(db.Devices);
    }

    [Fact]
    public async Task WeakPasswordDoesNotCreateChild()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var controller = new PairingController(db, scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>(),
            scope.ServiceProvider.GetRequiredService<JwtService>());
        Identity(controller, "parent");
        Assert.IsType<BadRequestObjectResult>(await controller.Confirm(Account("123")));
        Assert.Empty(db.Children); Assert.Empty(db.Devices);
    }

    [Fact]
    public async Task ChildCanRestoreOnlyItsEnrolledPhoneAfterOtp()
    {
        using var provider = Services(); using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>(); await Seed(db);
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var jwt = scope.ServiceProvider.GetRequiredService<JwtService>();
        var pairing = new PairingController(db, users, jwt); Identity(pairing, "parent");
        await pairing.Confirm(Account());
        var child = await db.Children.SingleAsync();
        var controller = new ChildSessionController(db, jwt);
        var dto = new ChildDeviceLoginDto { DeviceIdentifier = "test-phone", DeviceSecret = Qr };
        Identity(controller, "another-child", "Child");
        Assert.IsType<ForbidResult>(await controller.LoginDevice(dto));
        Identity(controller, child.UserId, "Child");
        Assert.IsType<OkObjectResult>(await controller.LoginDevice(dto));
        Assert.Single(db.Children); Assert.Single(db.Devices);
        Assert.Equal(Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Qr))),
            (await db.Devices.SingleAsync()).DeviceSecretHash);
    }
}
