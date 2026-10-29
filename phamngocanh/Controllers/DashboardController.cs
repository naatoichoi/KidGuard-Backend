using System.Globalization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.Models;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class DashboardController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public DashboardController(ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        // date theo yyyy-MM-dd, nếu bỏ trống dùng ngày hiện tại tại Việt Nam.
        private static bool TryGetDate(string? date, out DateTime selectedDate)
        {
            if (string.IsNullOrWhiteSpace(date))
            {
                selectedDate = DateTime.UtcNow.AddHours(7).Date;
                return true;
            }

            return DateTime.TryParseExact(date, "yyyy-MM-dd",
                CultureInfo.InvariantCulture, DateTimeStyles.None,
                out selectedDate);
        }

        // GET: api/Dashboard/parent?date=2026-10-29
        [HttpGet("parent")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> ParentDashboard([FromQuery] string? date = null)
        {
            string? parentId = _userManager.GetUserId(User);
            if (string.IsNullOrWhiteSpace(parentId)) return Unauthorized();
            if (!TryGetDate(date, out DateTime day))
                return BadRequest(new { message = "date phải theo định dạng yyyy-MM-dd." });

            var children = await _context.ParentChildren.AsNoTracking()
                .Where(pc => pc.ParentId == parentId && pc.IsActive && pc.Child.IsActive)
                .Select(pc => new { pc.ChildId, childName = pc.Child.FullName })
                .Distinct()
                .OrderBy(c => c.ChildId)
                .ToListAsync();

            var childIds = children.Select(c => c.ChildId).ToList();
            var devices = await _context.Devices.AsNoTracking()
                .Where(d => childIds.Contains(d.ChildId) && d.IsActive)
                .Select(d => new { d.Id, d.ChildId, d.DeviceName, d.LastSyncAt })
                .ToListAsync();

            var deviceIds = devices.Select(d => d.Id).ToList();
            var usage = await _context.DailyScreenTimes.AsNoTracking()
                .Where(u => deviceIds.Contains(u.DeviceId) && u.UsageDate == day)
                .GroupBy(u => u.DeviceId)
                .Select(g => new { deviceId = g.Key, totalSeconds = g.Sum(x => x.TotalSeconds) })
                .ToListAsync();

            var limits = await _context.ScreenTimeLimits.AsNoTracking()
                .Where(l => deviceIds.Contains(l.DeviceId) && l.IsEnabled && l.LimitType == "TOTAL")
                .Select(l => new { l.Id, l.DeviceId, l.DailyLimitMinutes })
                .ToListAsync();

            var limitIds = limits.Select(l => l.Id).ToList();
            var extensions = await _context.TimeExtensions.AsNoTracking()
                .Where(e => limitIds.Contains(e.ScreenTimeLimitId) && e.EffectiveDate == day)
                .GroupBy(e => e.ScreenTimeLimitId)
                .Select(g => new { limitId = g.Key, extraMinutes = g.Sum(x => x.ExtraMinutes) })
                .ToListAsync();

            int pendingCount = await _context.TimeRequests.AsNoTracking()
                .CountAsync(r => childIds.Contains(r.ChildId) && r.Status == "PENDING");
            int unreadNotifications = await _context.Notifications.AsNoTracking()
                .CountAsync(n => n.UserId == parentId && !n.IsRead);

            var childSummaries = children.Select(c =>
            {
                var childDevices = devices.Where(d => d.ChildId == c.ChildId)
                    .Select(d =>
                    {
                        long usedSeconds = usage.FirstOrDefault(u => u.deviceId == d.Id)?.totalSeconds ?? 0;
                        var limit = limits.FirstOrDefault(l => l.DeviceId == d.Id);
                        int extraMinutes = limit == null ? 0 :
                            extensions.FirstOrDefault(e => e.limitId == limit.Id)?.extraMinutes ?? 0;
                        int? effectiveLimit = limit == null ? null : limit.DailyLimitMinutes + extraMinutes;
                        return new
                        {
                            deviceId = d.Id,
                            deviceName = d.DeviceName,
                            d.LastSyncAt,
                            usedSeconds,
                            usedMinutes = (int)Math.Ceiling(usedSeconds / 60.0),
                            baseLimitMinutes = limit?.DailyLimitMinutes,
                            extraMinutes,
                            effectiveLimitMinutes = effectiveLimit,
                            remainingMinutes = effectiveLimit.HasValue
                                ? (int?)Math.Max(0, effectiveLimit.Value - (int)Math.Ceiling(usedSeconds / 60.0))
                                : null
                        };
                    }).ToList();
                return new
                {
                    childId = c.ChildId,
                    c.childName,
                    totalUsedMinutes = (int)Math.Ceiling(childDevices.Sum(d => d.usedSeconds) / 60.0),
                    devices = childDevices
                };
            }).ToList();

            return Ok(new
            {
                date = day.ToString("yyyy-MM-dd"),
                totalChildren = childSummaries.Count,
                totalDevices = devices.Count,
                pendingRequests = pendingCount,
                unreadNotifications,
                children = childSummaries
            });
        }

        // GET: api/Dashboard/child?date=2026-10-29
        [HttpGet("child")]
        [Authorize(Roles = "Child")]
        public async Task<IActionResult> ChildDashboard([FromQuery] string? date = null)
        {
            string? userId = _userManager.GetUserId(User);
            if (string.IsNullOrWhiteSpace(userId)) return Unauthorized();
            if (!TryGetDate(date, out DateTime day))
                return BadRequest(new { message = "date phải theo định dạng yyyy-MM-dd." });

            var child = await _context.Children.AsNoTracking()
                .Where(c => c.UserId == userId && c.IsActive)
                .Select(c => new { c.Id, c.FullName })
                .FirstOrDefaultAsync();
            if (child == null)
                return NotFound(new { message = "Không tìm thấy hồ sơ Child." });

            var devices = await _context.Devices.AsNoTracking()
                .Where(d => d.ChildId == child.Id && d.IsActive)
                .Select(d => new { d.Id, d.DeviceName, d.LastSyncAt })
                .ToListAsync();
            var deviceIds = devices.Select(d => d.Id).ToList();

            var usage = await _context.DailyScreenTimes.AsNoTracking()
                .Where(u => deviceIds.Contains(u.DeviceId) && u.UsageDate == day)
                .GroupBy(u => u.DeviceId)
                .Select(g => new { deviceId = g.Key, totalSeconds = g.Sum(x => x.TotalSeconds) })
                .ToListAsync();
            var limits = await _context.ScreenTimeLimits.AsNoTracking()
                .Where(l => deviceIds.Contains(l.DeviceId) && l.IsEnabled && l.LimitType == "TOTAL")
                .Select(l => new { l.Id, l.DeviceId, l.DailyLimitMinutes })
                .ToListAsync();
            var limitIds = limits.Select(l => l.Id).ToList();
            var extensions = await _context.TimeExtensions.AsNoTracking()
                .Where(e => limitIds.Contains(e.ScreenTimeLimitId) && e.EffectiveDate == day)
                .GroupBy(e => e.ScreenTimeLimitId)
                .Select(g => new { limitId = g.Key, extraMinutes = g.Sum(x => x.ExtraMinutes) })
                .ToListAsync();

            int pendingRequests = await _context.TimeRequests.AsNoTracking()
                .CountAsync(r => r.ChildId == child.Id && r.Status == "PENDING");
            int unreadNotifications = await _context.Notifications.AsNoTracking()
                .CountAsync(n => n.UserId == userId && !n.IsRead);

            var deviceSummaries = devices.Select(d =>
            {
                long usedSeconds = usage.FirstOrDefault(u => u.deviceId == d.Id)?.totalSeconds ?? 0;
                int usedMinutes = (int)Math.Ceiling(usedSeconds / 60.0);
                var limit = limits.FirstOrDefault(l => l.DeviceId == d.Id);
                int extraMinutes = limit == null ? 0 :
                    extensions.FirstOrDefault(e => e.limitId == limit.Id)?.extraMinutes ?? 0;
                int? effectiveLimit = limit == null ? null : limit.DailyLimitMinutes + extraMinutes;
                return new
                {
                    deviceId = d.Id,
                    deviceName = d.DeviceName,
                    d.LastSyncAt,
                    usedSeconds,
                    usedMinutes,
                    screenTimeLimitId = limit?.Id,
                    baseLimitMinutes = limit?.DailyLimitMinutes,
                    extraMinutes,
                    effectiveLimitMinutes = effectiveLimit,
                    remainingMinutes = effectiveLimit.HasValue
                        ? (int?)Math.Max(0, effectiveLimit.Value - usedMinutes)
                        : null
                };
            }).ToList();

            return Ok(new
            {
                date = day.ToString("yyyy-MM-dd"),
                childId = child.Id,
                childName = child.FullName,
                totalUsedMinutes = (int)Math.Ceiling(deviceSummaries.Sum(d => d.usedSeconds) / 60.0),
                pendingRequests,
                unreadNotifications,
                devices = deviceSummaries
            });
        }
    }
}
