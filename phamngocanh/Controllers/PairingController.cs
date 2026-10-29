
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;
using phamngocanh.Services;
using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PairingController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly JwtService _jwtService;

        public PairingController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager,
            JwtService jwtService)
        {
            _context = context;
            _userManager = userManager;
            _jwtService = jwtService;
        }

        private static string Hash(string value)
        {
            return Convert.ToHexString(
                SHA256.HashData(
                    Encoding.UTF8.GetBytes(
                        value.Trim().ToUpperInvariant())));
        }

        private static bool SecretMatches(
            string providedSecret,
            string storedHash)
        {
            try
            {
                byte[] actual = Convert.FromHexString(
                    Hash(providedSecret));

                byte[] expected =
                    Convert.FromHexString(storedHash);

                return CryptographicOperations
                    .FixedTimeEquals(actual, expected);
            }
            catch (FormatException)
            {
                return false;
            }
        }

        [HttpPost("create")]
        [AllowAnonymous]
        public async Task<IActionResult> Create(
            [FromBody] CreatePairingCodeDto dto)
        {
            string identifier = dto.DeviceIdentifier.Trim();
            string name = dto.DeviceName.Trim();

            if (string.IsNullOrWhiteSpace(identifier) ||
                string.IsNullOrWhiteSpace(name) ||
                dto.AndroidVersion?.Trim().Length > 30)
            {
                return BadRequest(new
                {
                    message = "Thông tin thiết bị không hợp lệ."
                });
            }

            if (await _context.Devices.AnyAsync(d =>
                d.DeviceIdentifier == identifier))
            {
                return Conflict(new
                {
                    message = "Thiết bị đã được liên kết."
                });
            }

            DateTime now = DateTime.UtcNow;

            var oldCodes = await _context.PairingCodes
                .Where(p =>
                    p.DeviceIdentifier == identifier &&
                    p.Status == "PENDING" &&
                    !p.IsRevoked)
                .ToListAsync();

            foreach (var oldCode in oldCodes)
            {
                oldCode.IsRevoked = true;
                oldCode.Status = "REVOKED";
            }

            string qrToken = Convert.ToHexString(
                RandomNumberGenerator.GetBytes(32));

            var pairing = new PairingCode
            {
                SetupTokenHash = Hash(qrToken),
                DeviceSecretHash = Hash(dto.DeviceSecret),
                DeviceIdentifier = identifier,
                DeviceName = name,
                AndroidVersion = dto.AndroidVersion?.Trim(),
                Status = "PENDING",
                CreatedAt = now,
                ExpiresAt = now.AddMinutes(5),
                IsRevoked = false
            };

            _context.PairingCodes.Add(pairing);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Tạo mã QR thành công.",
                pairingId = pairing.Id,
                qrData = qrToken,
                expiresInSeconds = 300
            });
        }

        [HttpPost("confirm")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> Confirm(
            [FromBody] ConfirmPairingDto dto)
        {
            string? parentId =
                User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(parentId))
                return Unauthorized();

            string childName = dto.ChildName.Trim();

            if (string.IsNullOrWhiteSpace(childName))
            {
                return BadRequest(new
                {
                    message = "Vui lòng nhập tên trẻ em."
                });
            }

            await using var transaction =
                await _context.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable);

            DateTime now = DateTime.UtcNow;

            var pairing = await _context.PairingCodes
                .FirstOrDefaultAsync(p =>
                    p.SetupTokenHash == Hash(dto.QrData));

            if (pairing == null)
            {
                return BadRequest(new
                {
                    message = "Mã QR không hợp lệ."
                });
            }

            if (pairing.IsRevoked ||
                pairing.Status != "PENDING" ||
                pairing.UsedAt != null)
            {
                return Conflict(new
                {
                    message = "Mã QR không còn hiệu lực."
                });
            }

            if (pairing.ExpiresAt <= now)
            {
                return BadRequest(new
                {
                    message = "Mã QR đã hết hạn."
                });
            }

            if (await _context.Devices.AnyAsync(d =>
                d.DeviceIdentifier ==
                    pairing.DeviceIdentifier))
            {
                return Conflict(new
                {
                    message = "Thiết bị đã được liên kết."
                });
            }

            var childUser = new ApplicationUser
            {
                UserName = "child_" +
                    Guid.NewGuid().ToString("N"),
                FullName = childName,
                IsActive = true,
                CreatedAt = now
            };

            var createResult =
                await _userManager.CreateAsync(childUser);

            if (!createResult.Succeeded)
            {
                return BadRequest(new
                {
                    message = "Không thể tạo tài khoản Child.",
                    errors = createResult.Errors
                        .Select(e => e.Description)
                });
            }

            var roleResult =
                await _userManager.AddToRoleAsync(
                    childUser, "Child");

            if (!roleResult.Succeeded)
            {
                return BadRequest(new
                {
                    message = "Không thể gán quyền Child.",
                    errors = roleResult.Errors
                        .Select(e => e.Description)
                });
            }

            var child = new Child
            {
                UserId = childUser.Id,
                FullName = childName,
                OtpRecipientParentId = parentId,
                CreatedAt = now,
                IsActive = true
            };

            _context.Children.Add(child);
            await _context.SaveChangesAsync();

            _context.ParentChildren.Add(new ParentChild
            {
                ParentId = parentId,
                ChildId = child.Id,
                Relationship = "Guardian",
                LinkedAt = now,
                IsActive = true
            });

            var device = new Device
            {
                ChildId = child.Id,
                DeviceIdentifier = pairing.DeviceIdentifier,
                DeviceSecretHash = pairing.DeviceSecretHash,
                DeviceName = pairing.DeviceName,
                AndroidVersion = pairing.AndroidVersion,
                Platform = "Android",
                IsActive = true,
                CreatedAt = now
            };

            _context.Devices.Add(device);

            pairing.ChildId = child.Id;
            pairing.CreatedBy = parentId;
            pairing.Status = "USED";
            pairing.UsedAt = now;

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new
            {
                message = "Ghép thiết bị thành công.",
                childId = child.Id,
                childName = child.FullName,
                device = new
                {
                    id = device.Id,
                    deviceName = device.DeviceName
                }
            });
        }

        [HttpPost("status")]
        [AllowAnonymous]
        public async Task<IActionResult> Status(
            [FromBody] PairingStatusDto dto)
        {
            var pairing = await _context.PairingCodes
                .AsNoTracking()
                .FirstOrDefaultAsync(p =>
                    p.SetupTokenHash == Hash(dto.QrData));

            if (pairing == null ||
                !SecretMatches(
                    dto.DeviceSecret,
                    pairing.DeviceSecretHash))
            {
                return Unauthorized(new
                {
                    message = "Thông tin ghép nối không hợp lệ."
                });
            }

            if (pairing.IsRevoked)
                return Ok(new { status = "REVOKED" });

            if (pairing.Status == "PENDING")
            {
                if (pairing.ExpiresAt <= DateTime.UtcNow)
                    return Ok(new { status = "EXPIRED" });

                return Ok(new { status = "PENDING" });
            }

            if (pairing.Status != "USED" ||
                pairing.ChildId == null)
            {
                return Ok(new
                {
                    status = pairing.Status
                });
            }

            var child = await _context.Children
                .Include(c => c.User)
                .FirstOrDefaultAsync(c =>
                    c.Id == pairing.ChildId &&
                    c.IsActive &&
                    c.User.IsActive);

            var device = await _context.Devices
                .FirstOrDefaultAsync(d =>
                    d.ChildId == pairing.ChildId &&
                    d.DeviceIdentifier ==
                        pairing.DeviceIdentifier &&
                    d.IsActive);

            if (child == null ||
                device == null ||
                !SecretMatches(
                    dto.DeviceSecret,
                    device.DeviceSecretHash))
            {
                return Unauthorized(new
                {
                    message = "Thiết bị không hợp lệ."
                });
            }

            string token =
                await _jwtService.GenerateTokenAsync(child.User);

            return Ok(new
            {
                status = "USED",
                childId = child.Id,
                deviceId = device.Id,
                deviceName = device.DeviceName,
                token
            });
        }

        // Cấp JWT mới khi Child mở ứng dụng.
        [HttpPost("refresh-token")]
        [AllowAnonymous]
        public async Task<IActionResult> RefreshToken(
            [FromBody] RefreshChildTokenDto dto)
        {
            var device = await _context.Devices
                .Include(d => d.Child)
                .ThenInclude(c => c.User)
                .FirstOrDefaultAsync(d =>
                    d.DeviceIdentifier ==
                        dto.DeviceIdentifier &&
                    d.IsActive &&
                    d.Child.IsActive &&
                    d.Child.User.IsActive);

            if (device == null ||
                !SecretMatches(
                    dto.DeviceSecret,
                    device.DeviceSecretHash))
            {
                return Unauthorized(new
                {
                    message = "Thiết bị chưa được xác thực."
                });
            }

            bool hasActiveParent =
                await _context.ParentChildren.AnyAsync(pc =>
                    pc.ChildId == device.ChildId &&
                    pc.IsActive);

            if (!hasActiveParent)
            {
                return Unauthorized(new
                {
                    message = "Liên kết phụ huynh không còn hiệu lực."
                });
            }

            string token =
                await _jwtService.GenerateTokenAsync(
                    device.Child.User);

            return Ok(new
            {
                token,
                childId = device.ChildId,
                deviceId = device.Id,
                deviceName = device.DeviceName
            });
        }
    }
}
