using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using phamngocanh.DTOs;
using phamngocanh.Models;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class LocationsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public LocationsController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        // POST: api/Locations/sync
        [HttpPost("sync")]
        [Authorize(Roles = "Child")]
        public async Task<IActionResult> SyncLocation([FromBody] SyncLocationDto dto)
        {
            string? userId = _userManager.GetUserId(User);
            if (string.IsNullOrWhiteSpace(userId)) return Unauthorized();

            var child = await _context.Children.AsNoTracking()
                .FirstOrDefaultAsync(c => c.UserId == userId && c.IsActive);
            if (child == null)
                return NotFound(new { message = "Không tìm thấy hồ sơ Child." });

            var device = await _context.Devices.FirstOrDefaultAsync(d =>
                d.Id == dto.DeviceId && d.ChildId == child.Id && d.IsActive);
            if (device == null)
                return BadRequest(new { message = "Thiết bị không thuộc Child này hoặc đã bị vô hiệu hóa." });

            if (!dto.Latitude.HasValue || !dto.Longitude.HasValue || !dto.RecordedAt.HasValue)
                return BadRequest(new { message = "Thiếu tọa độ hoặc thời gian ghi nhận." });

            DateTime recordedAt = dto.RecordedAt.Value.ToUniversalTime();
            DateTime now = DateTime.UtcNow;
            if (recordedAt > now.AddMinutes(5))
                return BadRequest(new { message = "Thời gian ghi nhận không được vượt quá hiện tại 5 phút." });

            if (recordedAt < now.AddDays(-30))
                return BadRequest(new { message = "Không nhận vị trí cũ hơn 30 ngày." });

            string source = (dto.Source ?? "FUSED").Trim().ToUpperInvariant();
            if (string.IsNullOrWhiteSpace(source) || source.Length > 20)
                return BadRequest(new { message = "Nguồn vị trí không hợp lệ." });

            var location = new Location
            {
                DeviceId = device.Id,
                Latitude = dto.Latitude.Value,
                Longitude = dto.Longitude.Value,
                AccuracyMeters = dto.AccuracyMeters,
                RecordedAt = recordedAt,
                ReceivedAt = now,
                Source = source
            };

            _context.Locations.Add(location);
            device.LastSyncAt = now;
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Đồng bộ vị trí thành công.",
                location = new
                {
                    location.Id,
                    location.DeviceId,
                    location.Latitude,
                    location.Longitude,
                    location.AccuracyMeters,
                    location.RecordedAt,
                    location.ReceivedAt,
                    location.Source
                }
            });
        }

        // GET: api/Locations/child/1/latest
        [HttpGet("child/{childId:int}/latest")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> GetLatestLocation(int childId)
        {
            if (!await ParentCanViewChild(childId))
                return Forbid();

            var latest = await _context.Locations.AsNoTracking()
                .Where(l => l.Device.ChildId == childId && l.Device.IsActive)
                .OrderByDescending(l => l.RecordedAt)
                .ThenByDescending(l => l.Id)
                .Select(l => new
                {
                    l.Id,
                    l.DeviceId,
                    deviceName = l.Device.DeviceName,
                    l.Latitude,
                    l.Longitude,
                    l.AccuracyMeters,
                    l.RecordedAt,
                    l.ReceivedAt,
                    l.Source
                })
                .FirstOrDefaultAsync();

            if (latest == null)
                return NotFound(new { message = "Child chưa có dữ liệu vị trí." });

            return Ok(new { childId, location = latest });
        }

        // GET: api/Locations/child/1/history?date=2026-10-29&page=1&pageSize=50
        [HttpGet("child/{childId:int}/history")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> GetLocationHistory(
            int childId,
            [FromQuery] DateTime? date,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            if (page < 1 || pageSize < 1 || pageSize > 100)
                return BadRequest(new { message = "page phải >= 1 và pageSize từ 1 đến 100." });

            if (!await ParentCanViewChild(childId))
                return Forbid();

            var query = _context.Locations.AsNoTracking()
                .Where(l => l.Device.ChildId == childId && l.Device.IsActive);

            if (date.HasValue)
            {
                DateTime start = date.Value.Date;
                DateTime end = start.AddDays(1);
                query = query.Where(l => l.RecordedAt >= start && l.RecordedAt < end);
            }

            int totalCount = await query.CountAsync();

            var locations = await query
                .OrderByDescending(l => l.RecordedAt)
                .ThenByDescending(l => l.Id)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(l => new
                {
                    l.Id,
                    l.DeviceId,
                    deviceName = l.Device.DeviceName,
                    l.Latitude,
                    l.Longitude,
                    l.AccuracyMeters,
                    l.RecordedAt,
                    l.ReceivedAt,
                    l.Source
                })
                .ToListAsync();

            return Ok(new
            {
                childId,
                date = date?.ToString("yyyy-MM-dd"),
                page,
                pageSize,
                totalCount,
                totalPages = (int)Math.Ceiling(totalCount / (double)pageSize),
                locations
            });
        }

        private async Task<bool> ParentCanViewChild(int childId)
        {
            string? parentId = _userManager.GetUserId(User);
            if (string.IsNullOrWhiteSpace(parentId)) return false;

            return await _context.ParentChildren.AsNoTracking().AnyAsync(pc =>
                pc.ParentId == parentId &&
                pc.ChildId == childId &&
                pc.IsActive &&
                pc.Child.IsActive);
        }
    }
}
