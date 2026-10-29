
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;
using System.Security.Claims;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = "Child")]
    public class UsageController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public UsageController(ApplicationDbContext context)
        {
            _context = context;
        }

        // POST: api/Usage/sync
        [HttpPost("sync")]
        public async Task<IActionResult> Sync(
            [FromBody] SyncAppUsageDto dto)
        {
            string? userId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var device = await _context.Devices
                .Include(d => d.Child)
                .FirstOrDefaultAsync(d =>
                    d.Id == dto.DeviceId &&
                    d.IsActive &&
                    d.Child.IsActive &&
                    d.Child.UserId == userId);

            if (device == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thiết bị thuộc tài khoản Child."
                });
            }

            DateTime usageDate = dto.UsageDate.Date;

            if (usageDate > DateTime.UtcNow.Date)
            {
                return BadRequest(new
                {
                    message = "Ngày sử dụng không được ở tương lai."
                });
            }

            if (dto.Apps.Any(a =>
                string.IsNullOrWhiteSpace(a.PackageName) ||
                string.IsNullOrWhiteSpace(a.AppName)))
            {
                return BadRequest(new
                {
                    message = "Thông tin ứng dụng không hợp lệ."
                });
            }

            // Không cho trùng package trong một lần đồng bộ.
            var apps = dto.Apps
                .Select(a => new
                {
                    PackageName = a.PackageName.Trim(),
                    AppName = a.AppName.Trim(),
                    a.DurationSeconds
                })
                .ToList();

            if (apps.GroupBy(a => a.PackageName,
                    StringComparer.OrdinalIgnoreCase)
                .Any(g => g.Count() > 1))
            {
                return BadRequest(new
                {
                    message = "Danh sách có ứng dụng bị trùng."
                });
            }

            // Dữ liệu gửi lên là tổng thời gian trong ngày.
            // Đồng bộ lại sẽ cập nhật, không cộng dồn.
            long totalSeconds = 0;

            try
            {
                checked
                {
                    foreach (var app in apps)
                        totalSeconds += app.DurationSeconds;
                }
            }
            catch (OverflowException)
            {
                return BadRequest(new
                {
                    message = "Tổng thời gian sử dụng không hợp lệ."
                });
            }

            if (totalSeconds > 86400)
            {
                return BadRequest(new
                {
                    message = "Tổng thời gian sử dụng vượt quá 24 giờ."
                });
            }

            DateTime now = DateTime.UtcNow;

            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            var existingUsages = await _context.AppUsages
                .Where(a =>
                    a.DeviceId == device.Id &&
                    a.UsageDate == usageDate)
                .ToListAsync();

            // Thay thế toàn bộ dữ liệu của ngày đó.
            _context.AppUsages.RemoveRange(existingUsages);

            foreach (var app in apps)
            {
                _context.AppUsages.Add(new AppUsage
                {
                    DeviceId = device.Id,
                    PackageName = app.PackageName,
                    AppName = app.AppName,
                    UsageDate = usageDate,
                    DurationSeconds = app.DurationSeconds,
                    LastSyncedAt = now
                });
            }

            var dailyUsage = await _context.DailyScreenTimes
                .FirstOrDefaultAsync(d =>
                    d.DeviceId == device.Id &&
                    d.UsageDate == usageDate);

            if (dailyUsage == null)
            {
                dailyUsage = new DailyScreenTime
                {
                    DeviceId = device.Id,
                    UsageDate = usageDate,
                    TotalSeconds = totalSeconds,
                    LastSyncedAt = now
                };

                _context.DailyScreenTimes.Add(dailyUsage);
            }
            else
            {
                dailyUsage.TotalSeconds = totalSeconds;
                dailyUsage.LastSyncedAt = now;
            }

            device.LastSyncAt = now;

            _context.DeviceSyncLogs.Add(new DeviceSyncLog
            {
                DeviceId = device.Id,
                SyncType = "USAGE",
                Status = "SUCCESS",
                StartedAt = now,
                CompletedAt = now,
                RecordsCount = apps.Count
            });

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new
            {
                message = "Đồng bộ thời gian sử dụng thành công.",
                deviceId = device.Id,
                usageDate = usageDate.ToString("yyyy-MM-dd"),
                appCount = apps.Count,
                totalSeconds,
                totalMinutes = Math.Round(totalSeconds / 60.0, 2),
                syncedAt = now
            });
        }
    }
}
