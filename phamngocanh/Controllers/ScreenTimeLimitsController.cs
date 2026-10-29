
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;

namespace phamngocanh.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ScreenTimeLimitsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public ScreenTimeLimitsController(
            ApplicationDbContext context)
        {
            _context = context;
        }

        // Chỉ Parent được tạo hoặc sửa giới hạn.
        [HttpPost]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> SetLimit(
            [FromBody] SetScreenTimeLimitDto dto)
        {
            var parentId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrEmpty(parentId))
                return Unauthorized();

            var device = await _context.Devices
                .AsNoTracking()
                .FirstOrDefaultAsync(d =>
                    d.Id == dto.DeviceId && d.IsActive);

            if (device == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thiết bị."
                });
            }

            var hasAccess = await _context.ParentChildren
                .AnyAsync(pc =>
                    pc.ParentId == parentId &&
                    pc.ChildId == device.ChildId &&
                    pc.IsActive);

            if (!hasAccess)
                return Forbid();

            var limitType =
                dto.LimitType.Trim().ToUpperInvariant();

            if (limitType != "APP" && limitType != "TOTAL")
            {
                return BadRequest(new
                {
                    message = "Loại giới hạn không hợp lệ."
                });
            }

            if (dto.DailyLimitMinutes < 1 ||
                dto.DailyLimitMinutes > 1440)
            {
                return BadRequest(new
                {
                    message = "Giới hạn phải từ 1 đến 1440 phút."
                });
            }

            if (limitType == "APP" &&
                string.IsNullOrWhiteSpace(dto.PackageName))
            {
                return BadRequest(new
                {
                    message = "Giới hạn APP cần PackageName."
                });
            }

            string? packageName = limitType == "TOTAL"
                ? null
                : dto.PackageName!.Trim().ToLowerInvariant();

            var limit = await _context.ScreenTimeLimits
                .FirstOrDefaultAsync(l =>
                    l.DeviceId == dto.DeviceId &&
                    l.LimitType == limitType &&
                    l.PackageName == packageName);

            bool isNew = limit == null;

            if (isNew)
            {
                limit = new ScreenTimeLimit
                {
                    DeviceId = dto.DeviceId,
                    LimitType = limitType,
                    PackageName = packageName,
                    CreatedAt = DateTime.UtcNow
                };

                _context.ScreenTimeLimits.Add(limit);
            }

            limit!.DailyLimitMinutes = dto.DailyLimitMinutes;
            limit.IsEnabled = dto.IsEnabled;
            limit.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = isNew
                    ? "Tạo giới hạn thành công."
                    : "Cập nhật giới hạn thành công.",
                limit = new
                {
                    limit.Id,
                    limit.DeviceId,
                    limit.LimitType,
                    limit.PackageName,
                    limit.DailyLimitMinutes,
                    limit.IsEnabled,
                    limit.UpdatedAt
                }
            });
        }

        // Parent xem thiết bị mình quản lý.
        // Child chỉ xem thiết bị thuộc tài khoản mình.
        [HttpGet("device/{deviceId:int}")]
        [Authorize(Roles = "Parent,Child")]
        public async Task<IActionResult> GetLimits(
            int deviceId)
        {
            var userId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var device = await _context.Devices
                .AsNoTracking()
                .FirstOrDefaultAsync(d =>
                    d.Id == deviceId && d.IsActive);

            if (device == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thiết bị."
                });
            }

            bool hasAccess = false;

            if (User.IsInRole("Parent"))
            {
                hasAccess = await _context.ParentChildren
                    .AnyAsync(pc =>
                        pc.ParentId == userId &&
                        pc.ChildId == device.ChildId &&
                        pc.IsActive);
            }
            else if (User.IsInRole("Child"))
            {
                hasAccess = await _context.Children
                    .AnyAsync(c =>
                        c.Id == device.ChildId &&
                        c.UserId == userId &&
                        c.IsActive);
            }

            if (!hasAccess)
                return Forbid();

            var limits = await _context.ScreenTimeLimits
                .AsNoTracking()
                .Where(l => l.DeviceId == deviceId)
                .OrderBy(l => l.LimitType)
                .ThenBy(l => l.PackageName)
                .Select(l => new
                {
                    l.Id,
                    l.DeviceId,
                    l.LimitType,
                    l.PackageName,
                    l.DailyLimitMinutes,
                    l.IsEnabled,
                    l.UpdatedAt
                })
                .ToListAsync();

            return Ok(limits);
        }
    }
}
