using System.Security.Claims;
using System.Security.Cryptography;
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

public class AuthProfileAndBiometricTests
{
    private sealed class SilentEmail : IEmailService
    {
        public Task SendEmailAsync(string toEmail, string subject, string htmlBody) =>
            Task.CompletedTask;
    }

    private static ServiceProvider Services()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddDataProtection().UseEphemeralDataProtectionProvider();
        services.AddDbContext<ApplicationDbContext>(options => options
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        services.AddIdentityCore<ApplicationUser>(options =>
        {
            options.Password.RequireDigit = true;
            options.Password.RequireLowercase = true;
            options.Password.RequireUppercase = false;
            options.Password.RequireNonAlphanumeric = false;
            options.Password.RequiredLength = 6;
        }).AddRoles<IdentityRole>().AddEntityFrameworkStores<ApplicationDbContext>().AddDefaultTokenProviders();
        services.AddSingleton<IConfiguration>(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)),
            ["Jwt:Issuer"] = "test",
            ["Jwt:Audience"] = "test",
            ["Jwt:ExpireMinutes"] = "120"
        }).Build());
        services.AddScoped<JwtService>();
        services.AddSingleton<IEmailService, SilentEmail>();
        return services.BuildServiceProvider();
    }

    private static AuthController Controller(IServiceScope scope)
    {
        var provider = scope.ServiceProvider;
        return new AuthController(
            provider.GetRequiredService<UserManager<ApplicationUser>>(),
            provider.GetRequiredService<RoleManager<IdentityRole>>(),
            provider.GetRequiredService<ApplicationDbContext>(),
            provider.GetRequiredService<IEmailService>(),
            provider.GetRequiredService<JwtService>(),
            provider.GetRequiredService<IConfiguration>());
    }

    private static void Identity(ControllerBase controller, string id)
    {
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                {
                    new Claim(ClaimTypes.NameIdentifier, id),
                    new Claim(ClaimTypes.Role, "Parent")
                }, "test"))
            }
        };
    }

    private static async Task<ApplicationUser> SeedParent(IServiceScope scope)
    {
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var roles = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
        if (!await roles.RoleExistsAsync("Parent"))
        {
            Assert.True((await roles.CreateAsync(new IdentityRole("Parent"))).Succeeded);
        }
        var user = new ApplicationUser
        {
            UserName = "guardian",
            Email = "parent@example.test",
            FullName = "Phụ huynh",
            IsActive = true
        };
        Assert.True((await users.CreateAsync(user, "parent123")).Succeeded);
        Assert.True((await users.AddToRoleAsync(user, "Parent")).Succeeded);
        return user;
    }

    [Fact]
    public async Task PasswordLoginDoesNotIssueTokenUntilOtp()
    {
        using var provider = Services();
        using var scope = provider.CreateScope();
        await SeedParent(scope);
        var controller = Controller(scope);
        var result = Assert.IsType<OkObjectResult>(await controller.Login(new LoginDto
        {
            UserName = "guardian",
            Password = "parent123"
        }));
        var payload = Assert.IsType<Dictionary<string, object>>(
            result.Value!.GetType()
                .GetProperties()
                .ToDictionary(p => p.Name, p => p.GetValue(result.Value)!));
        Assert.False(payload.ContainsKey("accessToken"));
        Assert.Contains("OTP", payload["message"]?.ToString());
    }

    [Fact]
    public async Task SecondLoginCanUseEnrolledBiometricWithoutOtp()
    {
        using var provider = Services();
        using var scope = provider.CreateScope();
        var user = await SeedParent(scope);
        var controller = Controller(scope);
        Identity(controller, user.Id);
        const string secret = "biometric-secret-value-32-chars!!";
        Assert.IsType<OkObjectResult>(await controller.EnrollBiometric(new EnrollBiometricDto
        {
            DeviceId = "phone-1",
            Secret = secret
        }));
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() };
        var login = Assert.IsType<OkObjectResult>(await controller.LoginBiometric(new LoginBiometricDto
        {
            UserName = "guardian",
            DeviceId = "phone-1",
            Secret = secret
        }));
        var token = login.Value!.GetType().GetProperty("accessToken")?.GetValue(login.Value)?.ToString();
        Assert.False(string.IsNullOrWhiteSpace(token));
    }

    [Fact]
    public async Task ParentCanUpdateProfileNameAndEmail()
    {
        using var provider = Services();
        using var scope = provider.CreateScope();
        var user = await SeedParent(scope);
        var controller = Controller(scope);
        Identity(controller, user.Id);
        var result = Assert.IsType<OkObjectResult>(await controller.UpdateProfile(new UpdateProfileDto
        {
            FullName = "Nguyễn Văn A",
            Email = "new@example.test"
        }));
        Assert.Equal("Nguyễn Văn A", result.Value!.GetType().GetProperty("fullName")?.GetValue(result.Value));
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var updated = await users.FindByIdAsync(user.Id);
        Assert.Equal("new@example.test", updated!.Email);
    }
}
