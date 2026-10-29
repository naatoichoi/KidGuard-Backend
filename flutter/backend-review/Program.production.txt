
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using phamngocanh.Data;
using phamngocanh.Models;
using phamngocanh.Services;

var builder = WebApplication.CreateBuilder(args);

// Trust only the configured reverse proxy, never arbitrary Internet headers.
if (IPAddress.TryParse(builder.Configuration["Proxy:KnownAddress"], out var proxyAddress))
{
    builder.Services.Configure<ForwardedHeadersOptions>(options =>
    {
        options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        options.KnownProxies.Add(proxyAddress);
    });
}

// 1. KẾT NỐI SQL SERVER
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")
    )
);

// 2. CẤU HÌNH ASP.NET CORE IDENTITY
builder.Services
    .AddIdentity<ApplicationUser, IdentityRole>(options =>
    {
        options.Password.RequireDigit = true;
        options.Password.RequireLowercase = true;
        options.Password.RequireUppercase = false;
        options.Password.RequireNonAlphanumeric = false;
        options.Password.RequiredLength = 6;

        options.User.RequireUniqueEmail = false;

        options.Lockout.DefaultLockoutTimeSpan =
            TimeSpan.FromMinutes(15);

        options.Lockout.MaxFailedAccessAttempts = 5;
        options.Lockout.AllowedForNewUsers = true;
    })
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// 3. ĐĂNG KÝ CÁC DỊCH VỤ
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<JwtService>();

// 4. CẤU HÌNH JWT AUTHENTICATION
string jwtKey = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException(
        "Chưa cấu hình Jwt:Key trong User Secrets.");

string jwtIssuer = builder.Configuration["Jwt:Issuer"]
    ?? throw new InvalidOperationException(
        "Chưa cấu hình Jwt:Issuer.");

string jwtAudience = builder.Configuration["Jwt:Audience"]
    ?? throw new InvalidOperationException(
        "Chưa cấu hình Jwt:Audience.");

byte[] jwtKeyBytes;

try
{
    jwtKeyBytes = Convert.FromBase64String(jwtKey);
}
catch (FormatException)
{
    throw new InvalidOperationException(
        "Jwt:Key phải là chuỗi Base64 hợp lệ.");
}

if (jwtKeyBytes.Length < 32 ||
    jwtKeyBytes.All(b => b == 0))
{
    throw new InvalidOperationException(
        "Jwt:Key phải là khóa ngẫu nhiên tối thiểu 32 byte.");
}

builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme =
            JwtBearerDefaults.AuthenticationScheme;

        options.DefaultChallengeScheme =
            JwtBearerDefaults.AuthenticationScheme;

        options.DefaultScheme =
            JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters =
            new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = jwtIssuer,

                ValidateAudience = true,
                ValidAudience = jwtAudience,

                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero,

                ValidateIssuerSigningKey = true,
                IssuerSigningKey =
                    new SymmetricSecurityKey(jwtKeyBytes),

                RequireSignedTokens = true,
                RequireExpirationTime = true
            };
    });

// 5. PHÂN QUYỀN
builder.Services.AddAuthorization();

// 6. CONTROLLERS
builder.Services.AddControllers();

// 7. CORS CHO FLUTTER
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutter", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

// 8. OPENAPI
builder.Services.AddOpenApi();

var app = builder.Build();

// Explicit deployment command; normal startup never changes the database schema.
if (args.Contains("--migrate"))
{
    await using var scope = app.Services.CreateAsyncScope();
    await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().Database.MigrateAsync();
    return;
}

app.UseForwardedHeaders();
app.MapGet("/health", async (ApplicationDbContext context) =>
{
    try
    {
        var ready = await context.Database.CanConnectAsync() &&
            !(await context.Database.GetPendingMigrationsAsync()).Any();
        return Results.StatusCode(ready ? 200 : 503);
    }
    catch { return Results.StatusCode(503); }
}).AllowAnonymous();

// 9. MIDDLEWARE
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseCors("AllowFlutter");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
