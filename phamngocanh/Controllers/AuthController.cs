
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;
using phamngocanh.Services;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly ApplicationDbContext _context;
        private readonly IEmailService _emailService;
        private readonly JwtService _jwtService;
        private readonly IConfiguration _configuration;

        public AuthController(
            UserManager<ApplicationUser> userManager,
            RoleManager<IdentityRole> roleManager,
            ApplicationDbContext context,
            IEmailService emailService,
            JwtService jwtService,
            IConfiguration configuration)
        {
            _userManager = userManager;
            _roleManager = roleManager;
            _context = context;
            _emailService = emailService;
            _jwtService = jwtService;
            _configuration = configuration;
        }

        // POST: api/Auth/register-parent
        [HttpPost("register-parent")]
        public async Task<IActionResult> RegisterParent(
            [FromBody] RegisterParentDto dto)
        {
            string userName = dto.UserName.Trim();
            string email = dto.Email.Trim();

            if (await _userManager.FindByNameAsync(userName) != null)
            {
                return Conflict(new
                {
                    message = "Tên đăng nhập đã tồn tại."
                });
            }

            if (await _userManager.FindByEmailAsync(email) != null)
            {
                return Conflict(new
                {
                    message = "Email đã được sử dụng."
                });
            }

            var user = new ApplicationUser
            {
                UserName = userName,
                Email = email,
                FullName = dto.FullName.Trim(),
                EmailConfirmed = false,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            var result = await _userManager.CreateAsync(
                user, dto.Password);

            if (!result.Succeeded)
            {
                return BadRequest(new
                {
                    message = "Đăng ký thất bại.",
                    errors = result.Errors.Select(e => e.Description)
                });
            }

            if (!await _roleManager.RoleExistsAsync("Parent"))
            {
                var roleResult = await _roleManager.CreateAsync(
                    new IdentityRole("Parent"));

                if (!roleResult.Succeeded)
                {
                    await _userManager.DeleteAsync(user);

                    return StatusCode(500, new
                    {
                        message = "Không thể tạo quyền Parent."
                    });
                }
            }

            var addRoleResult =
                await _userManager.AddToRoleAsync(user, "Parent");

            if (!addRoleResult.Succeeded)
            {
                await _userManager.DeleteAsync(user);

                return StatusCode(500, new
                {
                    message = "Không thể gán quyền Parent."
                });
            }

            return StatusCode(201, new
            {
                message = "Đăng ký tài khoản Parent thành công.",
                userId = user.Id,
                userName = user.UserName,
                email = user.Email,
                role = "Parent"
            });
        }

        // POST: api/Auth/login
        [HttpPost("login")]
        public async Task<IActionResult> Login(
            [FromBody] LoginDto dto)
        {
            var user = await _userManager.FindByNameAsync(
                dto.UserName.Trim());

            if (user == null || !user.IsActive)
            {
                return Unauthorized(new
                {
                    message = "Tên đăng nhập hoặc mật khẩu không đúng."
                });
            }

            if (await _userManager.IsLockedOutAsync(user))
            {
                return Unauthorized(new
                {
                    message = "Tài khoản tạm thời bị khóa. Vui lòng thử lại sau."
                });
            }

            bool validPassword =
                await _userManager.CheckPasswordAsync(
                    user, dto.Password);

            if (!validPassword)
            {
                await _userManager.AccessFailedAsync(user);

                return Unauthorized(new
                {
                    message = "Tên đăng nhập hoặc mật khẩu không đúng."
                });
            }

            // Xác định email nhận OTP theo vai trò
            string? recipientEmail;

            if (await _userManager.IsInRoleAsync(user, "Child"))
            {
                // Child nhận OTP qua email Parent
                var child = await _context.Children
                    .Include(c => c.OtpRecipientParent)
                    .FirstOrDefaultAsync(c => c.UserId == user.Id);

                recipientEmail = child?.OtpRecipientParent?.Email;
            }
            else
            {
                // Parent nhận OTP qua email của mình
                recipientEmail = user.Email;
            }

            if (string.IsNullOrWhiteSpace(recipientEmail))
            {
                return BadRequest(new
                {
                    message = "Tài khoản chưa được thiết lập email nhận OTP."
                });
            }

            DateTime now = DateTime.UtcNow;

            // Giới hạn gửi OTP: tối thiểu 60 giây/lần
            bool recentlySent = await _context.OtpCodes
                .AnyAsync(o =>
                    o.UserId == user.Id &&
                    o.Purpose == "LOGIN" &&
                    o.CreatedAt > now.AddSeconds(-60));

            if (recentlySent)
            {
                return StatusCode(429, new
                {
                    message = "Vui lòng chờ 60 giây trước khi yêu cầu OTP mới."
                });
            }

            string otp = RandomNumberGenerator
                .GetInt32(0, 1000000)
                .ToString("D6");

            string codeHash = HashOtp(user.Id, otp);

            // Vô hiệu hóa OTP đăng nhập cũ
            var oldOtps = await _context.OtpCodes
                .Where(o =>
                    o.UserId == user.Id &&
                    o.Purpose == "LOGIN" &&
                    o.UsedAt == null)
                .ToListAsync();

            foreach (var oldOtp in oldOtps)
            {
                oldOtp.UsedAt = now;
            }

            var otpRecord = new OtpCode
            {
                UserId = user.Id,
                CodeHash = codeHash,
                Purpose = "LOGIN",
                ExpiresAt = now.AddMinutes(5),
                AttemptCount = 0,
                CreatedAt = now
            };

            _context.OtpCodes.Add(otpRecord);
            await _context.SaveChangesAsync();

            string emailBody = $"""
                <h2>KidGuard - Xác thực đăng nhập</h2>
                <p>Mã OTP của bạn là:</p>
                <h1>{otp}</h1>
                <p>Mã có hiệu lực trong 5 phút.</p>
                <p>Nếu bạn không yêu cầu đăng nhập, hãy bỏ qua email này.</p>
                """;

            try
            {
                await _emailService.SendEmailAsync(
                    recipientEmail,
                    "KidGuard - Mã OTP đăng nhập",
                    emailBody);
            }
            catch
            {
                // Không trả chi tiết lỗi SMTP cho client
                _context.OtpCodes.Remove(otpRecord);
                await _context.SaveChangesAsync();

                return StatusCode(503, new
                {
                    message = "Không thể gửi OTP. Vui lòng thử lại sau."
                });
            }

            return Ok(new
            {
                message = "Đã gửi OTP. Vui lòng kiểm tra email.",
                expiresInSeconds = 300
            });
        }

        // POST: api/Auth/verify-otp
        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp(
            [FromBody] VerifyOtpDto dto)
        {
            var user = await _userManager.FindByNameAsync(
                dto.UserName.Trim());

            if (user == null || !user.IsActive)
            {
                return Unauthorized(new
                {
                    message = "Thông tin xác thực không hợp lệ."
                });
            }

            if (await _userManager.IsLockedOutAsync(user))
            {
                return Unauthorized(new
                {
                    message = "Tài khoản tạm thời bị khóa."
                });
            }

            DateTime now = DateTime.UtcNow;

            // Lấy OTP đăng nhập mới nhất chưa sử dụng
            var otpRecord = await _context.OtpCodes
                .Where(o =>
                    o.UserId == user.Id &&
                    o.Purpose == "LOGIN" &&
                    o.UsedAt == null)
                .OrderByDescending(o => o.CreatedAt)
                .ThenByDescending(o => o.Id)
                .FirstOrDefaultAsync();

            if (otpRecord == null)
            {
                return Unauthorized(new
                {
                    message = "Không tìm thấy OTP hợp lệ. Vui lòng đăng nhập lại."
                });
            }

            // Kiểm tra thời hạn OTP
            if (otpRecord.ExpiresAt <= now)
            {
                otpRecord.UsedAt = now;
                await _context.SaveChangesAsync();

                return Unauthorized(new
                {
                    message = "OTP đã hết hạn. Vui lòng đăng nhập lại."
                });
            }

            // Kiểm tra số lần nhập sai
            if (otpRecord.AttemptCount >= 5)
            {
                otpRecord.UsedAt = now;
                await _context.SaveChangesAsync();

                return StatusCode(429, new
                {
                    message = "OTP đã bị khóa do nhập sai quá 5 lần."
                });
            }

            string inputHash = HashOtp(user.Id, dto.Code);

            bool isValidOtp =
                CryptographicOperations.FixedTimeEquals(
                    Convert.FromHexString(otpRecord.CodeHash),
                    Convert.FromHexString(inputHash));

            if (!isValidOtp)
            {
                otpRecord.AttemptCount++;

                if (otpRecord.AttemptCount >= 5)
                {
                    otpRecord.UsedAt = now;
                }

                await _context.SaveChangesAsync();

                return Unauthorized(new
                {
                    message = otpRecord.AttemptCount >= 5
                        ? "OTP đã bị khóa do nhập sai 5 lần."
                        : "Mã OTP không chính xác.",
                    remainingAttempts =
                        Math.Max(0, 5 - otpRecord.AttemptCount)
                });
            }

            otpRecord.UsedAt = now;
            await _context.SaveChangesAsync();
            await _userManager.ResetAccessFailedCountAsync(user);
            return Ok(await SessionPayload(user, "Đăng nhập thành công."));
        }

        [HttpPost("enroll-biometric")]
        [Authorize]
        public async Task<IActionResult> EnrollBiometric(
            [FromBody] EnrollBiometricDto dto)
        {
            var user = await CurrentUser();
            if (user == null || !user.IsActive)
            {
                return Unauthorized(new { message = "Phiên đăng nhập không hợp lệ." });
            }

            string deviceId = dto.DeviceId.Trim();
            var existing = await _context.BiometricCredentials
                .FirstOrDefaultAsync(c => c.DeviceId == deviceId);
            DateTime now = DateTime.UtcNow;
            if (existing == null)
            {
                _context.BiometricCredentials.Add(new BiometricCredential
                {
                    UserId = user.Id,
                    DeviceId = deviceId,
                    SecretHash = HashOtp(user.Id, dto.Secret),
                    CreatedAt = now
                });
            }
            else
            {
                existing.UserId = user.Id;
                existing.SecretHash = HashOtp(user.Id, dto.Secret);
                existing.LastUsedAt = null;
            }

            await _context.SaveChangesAsync();
            return Ok(new { message = "Đã bật đăng nhập vân tay/khuôn mặt cho lần sau." });
        }

        [HttpPost("login-biometric")]
        public async Task<IActionResult> LoginBiometric(
            [FromBody] LoginBiometricDto dto)
        {
            var user = await _userManager.FindByNameAsync(dto.UserName.Trim());
            if (user == null || !user.IsActive)
            {
                return Unauthorized(new { message = "Không xác thực được sinh trắc học." });
            }

            var credential = await _context.BiometricCredentials
                .FirstOrDefaultAsync(c =>
                    c.UserId == user.Id &&
                    c.DeviceId == dto.DeviceId.Trim());
            if (credential == null)
            {
                return Unauthorized(new
                {
                    message = "Thiết bị chưa được đăng ký sinh trắc học. Hãy đăng nhập bằng mật khẩu và OTP."
                });
            }

            string inputHash = HashOtp(user.Id, dto.Secret);
            bool valid = CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(credential.SecretHash),
                Convert.FromHexString(inputHash));
            if (!valid)
            {
                return Unauthorized(new { message = "Không xác thực được sinh trắc học." });
            }

            credential.LastUsedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            await _userManager.ResetAccessFailedCountAsync(user);
            return Ok(await SessionPayload(user, "Đăng nhập bằng sinh trắc học thành công."));
        }

        [HttpGet("profile")]
        [Authorize]
        public async Task<IActionResult> GetProfile()
        {
            var user = await CurrentUser();
            if (user == null)
            {
                return Unauthorized(new { message = "Phiên đăng nhập không hợp lệ." });
            }

            var roles = await _userManager.GetRolesAsync(user);
            return Ok(new
            {
                id = user.Id,
                userName = user.UserName,
                fullName = user.FullName,
                email = user.Email,
                roles
            });
        }

        [HttpPut("profile")]
        [Authorize]
        public async Task<IActionResult> UpdateProfile(
            [FromBody] UpdateProfileDto dto)
        {
            var user = await CurrentUser();
            if (user == null || !user.IsActive)
            {
                return Unauthorized(new { message = "Phiên đăng nhập không hợp lệ." });
            }

            string fullName = dto.FullName.Trim();
            string? email = string.IsNullOrWhiteSpace(dto.Email)
                ? null
                : dto.Email.Trim();

            bool isParent = await _userManager.IsInRoleAsync(user, "Parent");
            if (isParent && string.IsNullOrWhiteSpace(email))
            {
                return BadRequest(new { message = "Phụ huynh cần email để nhận OTP." });
            }

            if (!string.IsNullOrWhiteSpace(email) &&
                !string.Equals(user.Email, email, StringComparison.OrdinalIgnoreCase))
            {
                var taken = await _userManager.FindByEmailAsync(email);
                if (taken != null && taken.Id != user.Id)
                {
                    return Conflict(new { message = "Email đã được sử dụng." });
                }
            }

            bool changingPassword = !string.IsNullOrWhiteSpace(dto.NewPassword);
            if (changingPassword)
            {
                if (string.IsNullOrWhiteSpace(dto.CurrentPassword))
                {
                    return BadRequest(new { message = "Nhập mật khẩu hiện tại để đổi mật khẩu." });
                }

                var passwordResult = await _userManager.ChangePasswordAsync(
                    user, dto.CurrentPassword, dto.NewPassword!);
                if (!passwordResult.Succeeded)
                {
                    return BadRequest(new
                    {
                        message = "Không đổi được mật khẩu.",
                        errors = passwordResult.Errors.Select(e => e.Description)
                    });
                }
            }

            user.FullName = fullName;
            if (email != null)
            {
                user.Email = email;
                user.NormalizedEmail = _userManager.NormalizeEmail(email);
            }

            var update = await _userManager.UpdateAsync(user);
            if (!update.Succeeded)
            {
                return BadRequest(new
                {
                    message = "Không lưu được hồ sơ.",
                    errors = update.Errors.Select(e => e.Description)
                });
            }

            var child = await _context.Children
                .FirstOrDefaultAsync(c => c.UserId == user.Id);
            if (child != null)
            {
                child.FullName = fullName;
                await _context.SaveChangesAsync();
            }

            var roles = await _userManager.GetRolesAsync(user);
            return Ok(new
            {
                message = "Đã cập nhật hồ sơ.",
                userName = user.UserName,
                fullName = user.FullName,
                email = user.Email,
                roles
            });
        }

        private async Task<ApplicationUser?> CurrentUser()
        {
            string? userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
            {
                return null;
            }

            return await _userManager.FindByIdAsync(userId);
        }

        private async Task<object> SessionPayload(
            ApplicationUser user,
            string message)
        {
            string token = await _jwtService.GenerateTokenAsync(user);
            var roles = await _userManager.GetRolesAsync(user);
            return new
            {
                message,
                accessToken = token,
                tokenType = "Bearer",
                expiresInSeconds = int.Parse(
                    _configuration["Jwt:ExpireMinutes"] ?? "120") * 60,
                user = new
                {
                    id = user.Id,
                    userName = user.UserName,
                    fullName = user.FullName,
                    email = user.Email,
                    roles
                }
            };
        }

        private static string HashOtp(string userId, string otp)
        {
            byte[] bytes = SHA256.HashData(
                Encoding.UTF8.GetBytes($"{userId}:{otp}"));

            return Convert.ToHexString(bytes);
        }
    }
}
