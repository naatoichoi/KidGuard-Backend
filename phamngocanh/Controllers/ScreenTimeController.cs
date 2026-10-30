
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;
using System.Security.Claims;
using System.Text.Json;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class ScreenTimeController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public ScreenTimeController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        // POST: api/ScreenTime/sync
        [HttpPost("sync")]
        [Authorize(Roles = "Child")]
        public async Task<IActionResult> Sync(
            [FromBody] SyncAppUsageDto dto)
        {
            string? userId =
                _userManager.GetUserId(User)
                ?? User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User.FindFirstValue("sub");

            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new
                {
                    message = "Không xác định được tài khoản Child."
                });
            }

            var device = await _context.Devices
                .Include(d => d.Child)
                .FirstOrDefaultAsync(d =>
                    d.Id == dto.DeviceId &&
                    d.IsActive);

            if (device == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thiết bị."
                });
            }

            if (device.Child.UserId != userId ||
                !device.Child.IsActive)
            {
                return StatusCode(403, new
                {
                    message = "Bạn không có quyền đồng bộ thiết bị này."
                });
            }

            DateTime usageDate = dto.UsageDate.Date;
            DateTime today = DateTime.UtcNow.Date;

            if (usageDate > today)
            {
                return BadRequest(new
                {
                    message = "Ngày sử dụng không được ở tương lai."
                });
            }

            if (usageDate < today.AddDays(-30))
            {
                return BadRequest(new
                {
                    message = "Chỉ hỗ trợ đồng bộ dữ liệu trong 30 ngày gần nhất."
                });
            }

            if (dto.Apps == null || dto.Apps.Count == 0)
            {
                return BadRequest(new
                {
                    message = "Danh sách ứng dụng không được rỗng."
                });
            }

            var apps = dto.Apps
                .Select(a => new
                {
                    PackageName = a.PackageName?.Trim() ?? "",
                    AppName = a.AppName?.Trim() ?? "",
                    a.DurationSeconds
                })
                .ToList();

            if (apps.Any(a =>
                string.IsNullOrWhiteSpace(a.PackageName) ||
                string.IsNullOrWhiteSpace(a.AppName) ||
                a.DurationSeconds < 0))
            {
                return BadRequest(new
                {
                    message = "Thông tin ứng dụng không hợp lệ."
                });
            }

            if (apps.GroupBy(
                    a => a.PackageName,
                    StringComparer.OrdinalIgnoreCase)
                .Any(g => g.Count() > 1))
            {
                return BadRequest(new
                {
                    message = "Danh sách có package name bị trùng."
                });
            }

            if (apps.Any(a => a.DurationSeconds > 86400))
            {
                return BadRequest(new
                {
                    message = "Thời gian sử dụng ứng dụng vượt quá 24 giờ."
                });
            }

            long totalSeconds = 0;

            foreach (var app in apps)
            {
                if (totalSeconds > 86400 - app.DurationSeconds)
                {
                    return BadRequest(new
                    {
                        message = "Tổng thời gian sử dụng vượt quá 24 giờ."
                    });
                }

                totalSeconds += app.DurationSeconds;
            }

            DateTime now = DateTime.UtcNow;

            var existingUsages = await _context.AppUsages
                .Where(a =>
                    a.DeviceId == dto.DeviceId &&
                    a.UsageDate == usageDate)
                .ToListAsync();

            foreach (var app in apps)
            {
                var existing = existingUsages.FirstOrDefault(a =>
                    string.Equals(
                        a.PackageName,
                        app.PackageName,
                        StringComparison.OrdinalIgnoreCase));

                if (existing != null)
                {
                    existing.AppName = app.AppName;
                    existing.DurationSeconds = app.DurationSeconds;
                    existing.LastSyncedAt = now;
                }
                else
                {
                    _context.AppUsages.Add(new AppUsage
                    {
                        DeviceId = dto.DeviceId,
                        PackageName = app.PackageName,
                        AppName = app.AppName,
                        UsageDate = usageDate,
                        DurationSeconds = app.DurationSeconds,
                        LastSyncedAt = now
                    });
                }
            }

            var submittedPackages = apps
                .Select(a => a.PackageName)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            var removedUsages = existingUsages
                .Where(a => !submittedPackages.Contains(a.PackageName))
                .ToList();

            _context.AppUsages.RemoveRange(removedUsages);

            var daily = await _context.DailyScreenTimes
                .FirstOrDefaultAsync(d =>
                    d.DeviceId == dto.DeviceId &&
                    d.UsageDate == usageDate);

            if (daily == null)
            {
                _context.DailyScreenTimes.Add(
                    new DailyScreenTime
                    {
                        DeviceId = dto.DeviceId,
                        UsageDate = usageDate,
                        TotalSeconds = totalSeconds,
                        LastSyncedAt = now
                    });
            }
            else
            {
                daily.TotalSeconds = totalSeconds;
                daily.LastSyncedAt = now;
            }

            device.LastSyncAt = now;

            await _context.SaveChangesAsync();

            // Chỉ cảnh báo cho dữ liệu của ngày hiện tại.
            // Quy ước ngày hiện tại đang dùng UTC,
            // giống API đồng bộ hiện có.
            int notificationsCreated = 0;

            if (usageDate == today)
            {
                notificationsCreated =
                    await CreateScreenTimeNotifications(
                        device,
                        apps.Select(a => (
                            a.PackageName,
                            a.DurationSeconds
                        )).ToList(),
                        totalSeconds,
                        usageDate);
            }

            return Ok(new
            {
                message = "Đồng bộ thời gian sử dụng thành công.",
                deviceId = dto.DeviceId,
                usageDate = usageDate.ToString("yyyy-MM-dd"),
                appCount = apps.Count,
                totalSeconds,
                totalMinutes = Math.Round(totalSeconds / 60.0, 2),
                notificationsCreated,
                syncedAt = now
            });
        }

        // GET: api/ScreenTime/child/1?date=2026-10-29
        [HttpGet("child/{childId:int}")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> GetChildScreenTime(
            int childId,
            [FromQuery] DateTime? date)
        {
            string? parentId =
                _userManager.GetUserId(User)
                ?? User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User.FindFirstValue("sub");

            if (string.IsNullOrWhiteSpace(parentId))
            {
                return Unauthorized(new
                {
                    message = "Không xác định được tài khoản Parent."
                });
            }

            bool hasAccess = await _context.ParentChildren
                .AnyAsync(pc =>
                    pc.ParentId == parentId &&
                    pc.ChildId == childId &&
                    pc.IsActive &&
                    pc.Child.IsActive);

            if (!hasAccess)
            {
                return StatusCode(403, new
                {
                    message = "Bạn không có quyền xem dữ liệu của Child này."
                });
            }

            DateTime selectedDate =
                (date ?? DateTime.UtcNow).Date;

            var child = await _context.Children
                .AsNoTracking()
                .FirstOrDefaultAsync(c => c.Id == childId);

            var devices = await _context.Devices
                .AsNoTracking()
                .Where(d =>
                    d.ChildId == childId &&
                    d.IsActive)
                .Select(d => new
                {
                    d.Id,
                    d.DeviceName,
                    d.LastSyncAt
                })
                .ToListAsync();

            var deviceIds = devices.Select(d => d.Id).ToList();

            var dailyRecords = await _context.DailyScreenTimes
                .AsNoTracking()
                .Where(d =>
                    deviceIds.Contains(d.DeviceId) &&
                    d.UsageDate == selectedDate)
                .ToListAsync();

            var appRecords = await _context.AppUsages
                .AsNoTracking()
                .Where(a =>
                    deviceIds.Contains(a.DeviceId) &&
                    a.UsageDate == selectedDate)
                .OrderByDescending(a => a.DurationSeconds)
                .ToListAsync();

            long totalSeconds =
                dailyRecords.Sum(d => d.TotalSeconds);

            var deviceStatistics = devices.Select(device =>
            {
                long deviceTotal = dailyRecords
                    .Where(d => d.DeviceId == device.Id)
                    .Sum(d => d.TotalSeconds);

                var deviceApps = appRecords
                    .Where(a => a.DeviceId == device.Id)
                    .OrderByDescending(a => a.DurationSeconds)
                    .Select(a => new
                    {
                        a.PackageName,
                        a.AppName,
                        a.DurationSeconds,
                        durationMinutes = Math.Round(
                            a.DurationSeconds / 60.0, 2)
                    })
                    .ToList();

                return new
                {
                    deviceId = device.Id,
                    deviceName = device.DeviceName,
                    lastSyncAt = device.LastSyncAt,
                    totalSeconds = deviceTotal,
                    totalMinutes = Math.Round(
                        deviceTotal / 60.0, 2),
                    apps = deviceApps
                };
            }).ToList();

            return Ok(new
            {
                childId,
                childName = child?.FullName,
                usageDate = selectedDate.ToString("yyyy-MM-dd"),
                deviceCount = devices.Count,
                totalSeconds,
                totalMinutes = Math.Round(
                    totalSeconds / 60.0, 2),
                devices = deviceStatistics
            });
        }

        // GET: api/ScreenTime/limits/status/1
        [HttpGet("limits/status/{deviceId:int}")]
        [Authorize(Roles = "Parent,Child")]
        public async Task<IActionResult> GetLimitStatus(
            int deviceId,
            [FromQuery] DateTime? date)
        {
            string? userId =
                _userManager.GetUserId(User)
                ?? User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User.FindFirstValue("sub");

            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized();
            }

            var device = await _context.Devices
                .AsNoTracking()
                .Include(d => d.Child)
                .FirstOrDefaultAsync(d =>
                    d.Id == deviceId &&
                    d.IsActive &&
                    d.Child.IsActive);

            if (device == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thiết bị."
                });
            }

            bool isChild =
                device.Child.UserId == userId &&
                User.IsInRole("Child");

            bool isParent = false;

            if (User.IsInRole("Parent"))
            {
                isParent = await _context.ParentChildren
                    .AnyAsync(pc =>
                        pc.ParentId == userId &&
                        pc.ChildId == device.ChildId &&
                        pc.IsActive);
            }

            if (!isChild && !isParent)
            {
                return StatusCode(403, new
                {
                    message = "Bạn không có quyền xem thiết bị này."
                });
            }

            DateTime selectedDate =
                (date ?? DateTime.UtcNow).Date;

            var limits = await _context.ScreenTimeLimits
                .AsNoTracking()
                .Where(l =>
                    l.DeviceId == deviceId &&
                    l.IsEnabled)
                .ToListAsync();

            var usages = await _context.AppUsages
                .AsNoTracking()
                .Where(a =>
                    a.DeviceId == deviceId &&
                    a.UsageDate == selectedDate)
                .ToListAsync();

            var daily = await _context.DailyScreenTimes
                .AsNoTracking()
                .FirstOrDefaultAsync(d =>
                    d.DeviceId == deviceId &&
                    d.UsageDate == selectedDate);

            long totalSeconds = daily?.TotalSeconds ?? 0;

            // Lấy tổng số phút được Parent duyệt thêm cho đúng ngày.
            var limitIds = limits.Select(l => l.Id).ToList();
            var extensions = await _context.TimeExtensions
                .AsNoTracking()
                .Where(e =>
                    limitIds.Contains(e.ScreenTimeLimitId) &&
                    e.EffectiveDate == selectedDate &&
                    e.TimeRequest.Status == "APPROVED")
                .GroupBy(e => e.ScreenTimeLimitId)
                .Select(g => new
                {
                    LimitId = g.Key,
                    ExtraMinutes = g.Sum(e => e.ExtraMinutes)
                })
                .ToListAsync();

            var extraMinutesByLimit = extensions.ToDictionary(
                e => e.LimitId, e => e.ExtraMinutes);

            var results = limits.Select(limit =>
            {
                long usedSeconds;

                if (limit.LimitType == "APP")
                {
                    usedSeconds = usages
                        .Where(a => string.Equals(
                            a.PackageName,
                            limit.PackageName,
                            StringComparison.OrdinalIgnoreCase))
                        .Sum(a => a.DurationSeconds);
                }
                else
                {
                    usedSeconds = totalSeconds;
                }

                int extraMinutes = extraMinutesByLimit.GetValueOrDefault(limit.Id);
                long effectiveLimitMinutes =
                    (long)limit.DailyLimitMinutes + extraMinutes;

                double usedMinutes = usedSeconds / 60.0;
                double percentage = effectiveLimitMinutes > 0
                    ? usedMinutes / effectiveLimitMinutes * 100
                    : 0;

                double remainingMinutes = Math.Max(
                    0,
                    effectiveLimitMinutes - usedMinutes);

                string status;
                string message;

                if (percentage >= 100)
                {
                    status = "EXCEEDED";
                    message = "Đã hết thời gian sử dụng cho phép.";
                }
                else if (percentage >= 80)
                {
                    status = "WARNING";
                    message = "Sắp hết thời gian sử dụng.";
                }
                else
                {
                    status = "NORMAL";
                    message = "Thời gian sử dụng vẫn trong giới hạn.";
                }

                return new
                {
                    limitId = limit.Id,
                    limitType = limit.LimitType,
                    packageName = limit.PackageName,
                    dailyLimitMinutes = limit.DailyLimitMinutes,
                    extraMinutes,
                    effectiveLimitMinutes,
                    usedMinutes = Math.Round(usedMinutes, 2),
                    remainingMinutes = Math.Round(
                        remainingMinutes, 2),
                    percentage = Math.Round(percentage, 2),
                    status,
                    message
                };
            }).ToList();

            return Ok(new
            {
                deviceId,
                usageDate = selectedDate.ToString("yyyy-MM-dd"),
                limits = results
            });
        }

        [HttpGet("app-lock/{deviceId:int}")]
        [Authorize(Roles = "Parent,Child")]
        [ProducesResponseType(typeof(AppLockStatusDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetAppLockStatus(int deviceId,
            [FromQuery] string? packageName)
        {
            var package = packageName?.Trim();
            if (string.IsNullOrWhiteSpace(package) || package.Length > 255 ||
                !System.Text.RegularExpressions.Regex.IsMatch(package,
                    @"\A[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*\z"))
            {
                return BadRequest(new { message = "Nhập packageName Android hợp lệ, ví dụ com.google.android.youtube." });
            }

            // Reuse the existing authorization, daily usage and approved-extension calculation.
            // The old endpoint and its response contract remain unchanged.
            var result = await GetLimitStatus(deviceId, null);
            if (result is not OkObjectResult ok) return result;
            var payload = JsonSerializer.SerializeToElement(ok.Value);
            var matches = payload.GetProperty("limits").EnumerateArray()
                .Where(limit => limit.GetProperty("limitType").GetString() == "APP" &&
                    string.Equals(limit.GetProperty("packageName").GetString(), package,
                        StringComparison.OrdinalIgnoreCase)).ToArray();
            // Prefer an exhausted rule if older data contains multiple enabled APP rules.
            var selected = matches.OrderBy(limit => limit.GetProperty("remainingMinutes").GetDouble())
                .ThenBy(limit => limit.GetProperty("limitId").GetInt32()).FirstOrDefault();
            var hasLimit = matches.Length > 0;
            var status = hasLimit ? selected.GetProperty("status").GetString()! : "NO_LIMIT";
            var blocked = status == "EXCEEDED";
            return Ok(new AppLockStatusDto
            {
                DeviceId = deviceId,
                PackageName = hasLimit ? selected.GetProperty("packageName").GetString()! : package,
                UsageDate = payload.GetProperty("usageDate").GetString()!,
                ShouldBlock = blocked,
                Action = blocked ? "BLOCK_APP" : "ALLOW_APP",
                Status = status,
                LimitId = hasLimit ? selected.GetProperty("limitId").GetInt32() : null,
                UsedMinutes = hasLimit ? selected.GetProperty("usedMinutes").GetDouble() : null,
                RemainingMinutes = hasLimit ? selected.GetProperty("remainingMinutes").GetDouble() : null,
                EffectiveLimitMinutes = hasLimit ? selected.GetProperty("effectiveLimitMinutes").GetInt64() : null,
                Message = blocked ? "Ứng dụng đã hết thời gian; máy trẻ cần hiển thị màn hình chặn."
                    : hasLimit ? "Ứng dụng còn thời gian sử dụng."
                    : "Ứng dụng không có giới hạn APP đang bật."
            });
        }

        // Tạo thông báo cho Child và Parent
        private async Task<int> CreateScreenTimeNotifications(
            Device device,
            List<(string PackageName, long DurationSeconds)> apps,
            long totalSeconds,
            DateTime usageDate)
        {
            var limits = await _context.ScreenTimeLimits
                .AsNoTracking()
                .Where(l =>
                    l.DeviceId == device.Id &&
                    l.IsEnabled)
                .ToListAsync();

            if (limits.Count == 0)
            {
                return 0;
            }

            // Cảnh báo cũng phải dựa trên giới hạn đã được gia hạn.
            var limitIds = limits.Select(l => l.Id).ToList();
            var extensions = await _context.TimeExtensions
                .AsNoTracking()
                .Where(e =>
                    limitIds.Contains(e.ScreenTimeLimitId) &&
                    e.EffectiveDate == usageDate &&
                    e.TimeRequest.Status == "APPROVED")
                .GroupBy(e => e.ScreenTimeLimitId)
                .Select(g => new
                {
                    LimitId = g.Key,
                    ExtraMinutes = g.Sum(e => e.ExtraMinutes)
                })
                .ToListAsync();

            var extraMinutesByLimit = extensions.ToDictionary(
                e => e.LimitId, e => e.ExtraMinutes);

            var parentIds = await _context.ParentChildren
                .AsNoTracking()
                .Where(pc =>
                    pc.ChildId == device.ChildId &&
                    pc.IsActive)
                .Select(pc => pc.ParentId)
                .ToListAsync();

            var recipients = parentIds
                .Append(device.Child.UserId)
                .Where(id => !string.IsNullOrWhiteSpace(id))
                .Distinct()
                .ToList();

            string dateText = usageDate.ToString("yyyy-MM-dd");
            DateTime now = DateTime.UtcNow;
            int created = 0;

            foreach (var limit in limits)
            {
                long usedSeconds = limit.LimitType == "APP"
                    ? apps
                        .Where(a => string.Equals(
                            a.PackageName,
                            limit.PackageName,
                            StringComparison.OrdinalIgnoreCase))
                        .Sum(a => a.DurationSeconds)
                    : totalSeconds;

                long effectiveLimitMinutes =
                    (long)limit.DailyLimitMinutes +
                    extraMinutesByLimit.GetValueOrDefault(limit.Id);
                long allowedSeconds = effectiveLimitMinutes * 60;

                if (allowedSeconds <= 0)
                {
                    continue;
                }

                // Chưa đạt 80% thì không cần cảnh báo.
                if (usedSeconds * 100 < allowedSeconds * 80)
                {
                    continue;
                }

                string type = usedSeconds >= allowedSeconds
                    ? "SCREEN_TIME_EXCEEDED"
                    : "SCREEN_TIME_WARNING";

                string subject = limit.LimitType == "APP"
                    ? $"Ứng dụng {limit.PackageName}"
                    : $"Thiết bị {device.DeviceName}";

                string title = type == "SCREEN_TIME_EXCEEDED"
                    ? "Đã hết thời gian sử dụng"
                    : "Sắp hết thời gian sử dụng";

                double usedMinutes =
                    Math.Round(usedSeconds / 60.0, 2);

                // Gắn ngày vào nội dung để chống trùng
                // theo từng ngày sử dụng.
                string message =
                    $"{subject} đã sử dụng {usedMinutes} " +
                    $"/ {effectiveLimitMinutes} phút " +
                    $"trong ngày {dateText}.";

                if (type == "SCREEN_TIME_WARNING")
                {
                    message += " Sắp hết thời gian cho phép.";
                }
                else
                {
                    message += " Đã đạt hoặc vượt giới hạn.";
                }

                foreach (string recipientId in recipients)
                {
                    // Mỗi người, mỗi giới hạn, mỗi ngày,
                    // mỗi mức cảnh báo chỉ tạo một lần.
                    bool exists = await _context.Notifications
                        .AnyAsync(n =>
                            n.UserId == recipientId &&
                            n.Type == type &&
                            n.ReferenceId == limit.Id &&
                            n.Message.Contains(dateText));

                    if (exists)
                    {
                        continue;
                    }

                    _context.Notifications.Add(new Notification
                    {
                        UserId = recipientId,
                        Title = title,
                        Message = message,
                        Type = type,
                        ReferenceId = limit.Id,
                        IsRead = false,
                        CreatedAt = now
                    });

                    created++;
                }
            }

            if (created > 0)
            {
                await _context.SaveChangesAsync();
            }

            return created;
        }
    }
}
