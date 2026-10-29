using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.Services;
using phamngocanh.Models;

namespace phamngocanh.Controllers;

[ApiController]
[Route("api/Pairing")]
public class ChildSessionController(ApplicationDbContext context, JwtService jwtService) : ControllerBase
{
    // Also upgrades legacy QR accounts that were created without a password.
    [HttpPut("child/{id:int}/account")]
    [Authorize(Roles = "Parent")]
    public async Task<IActionResult> UpdateAccount(int id, ChildAccountUpdateDto dto,
        [FromServices] UserManager<ApplicationUser> users)
    {
        var parentId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(parentId)) return Unauthorized();
        var child = await context.Children.Include(c => c.User)
            .FirstOrDefaultAsync(c => c.Id == id && c.IsActive && c.User.IsActive);
        if (child == null) return NotFound();
        if (!await context.ParentChildren.AnyAsync(pc => pc.ChildId == id && pc.ParentId == parentId && pc.IsActive))
            return Forbid();
        await using var transaction = await context.Database.BeginTransactionAsync();
        var nameResult = await users.SetUserNameAsync(child.User, dto.UserName.Trim());
        if (!nameResult.Succeeded)
            return BadRequest(new { message = "Không đổi được tên đăng nhập.", errors = nameResult.Errors.Select(e => e.Description) });
        var resetToken = await users.GeneratePasswordResetTokenAsync(child.User);
        var result = await users.ResetPasswordAsync(child.User, resetToken, dto.Password);
        if (!result.Succeeded)
            return BadRequest(new { message = "Không đặt được mật khẩu.", errors = result.Errors.Select(e => e.Description) });
        child.FullName = dto.ChildName.Trim();
        child.User.FullName = child.FullName;
        await context.SaveChangesAsync();
        await transaction.CommitAsync();
        return Ok(new { message = "Đã lưu tài khoản đăng nhập của con.", userName = child.User.UserName });
    }
    // Only a Child authenticated with username/password + email OTP can restore
    // a previously paired device. QR is not needed again on this device.
    [HttpPost("login-device")]
    [Authorize(Roles = "Child")]
    public async Task<IActionResult> LoginDevice(ChildDeviceLoginDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId)) return Unauthorized();
        var device = await context.Devices.Include(d => d.Child).ThenInclude(c => c.User)
            .FirstOrDefaultAsync(d => d.DeviceIdentifier == dto.DeviceIdentifier && d.IsActive);
        if (device == null)
            return Conflict(new { message = "Điện thoại chưa được ghép. Hãy nhờ phụ huynh quét QR lần đầu." });
        if (device.Child.UserId != userId) return Forbid();
        if (!device.Child.IsActive || !device.Child.User.IsActive ||
            !await context.ParentChildren.AnyAsync(pc => pc.ChildId == device.ChildId && pc.IsActive))
            return Forbid();

        device.DeviceSecretHash = Convert.ToHexString(SHA256.HashData(
            Encoding.UTF8.GetBytes(dto.DeviceSecret.Trim().ToUpperInvariant())));
        await context.SaveChangesAsync();
        return Ok(new {
            token = await jwtService.GenerateTokenAsync(device.Child.User),
            deviceId = device.Id, childId = device.ChildId, deviceName = device.DeviceName
        });
    }
}

public class ChildDeviceLoginDto
{
    [Required, StringLength(100, MinimumLength = 1)]
    public string DeviceIdentifier { get; set; } = string.Empty;
    [Required, RegularExpression("^[0-9A-Fa-f]{64}$")]
    public string DeviceSecret { get; set; } = string.Empty;
}

public class ChildAccountUpdateDto
{
    [Required, StringLength(100)]
    public string ChildName { get; set; } = string.Empty;
    [Required, StringLength(50, MinimumLength = 3), RegularExpression(@"^[a-zA-Z0-9._@+\-]+$")]
    public string UserName { get; set; } = string.Empty;
    [Required, StringLength(100, MinimumLength = 6)]
    public string Password { get; set; } = string.Empty;
    [Required, Compare(nameof(Password))]
    public string ConfirmPassword { get; set; } = string.Empty;
}
