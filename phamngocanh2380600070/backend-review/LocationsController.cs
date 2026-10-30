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
                Source = source,
                Address = string.IsNullOrWhiteSpace(dto.Address) ? null : dto.Address.Trim()
            };

            _context.Locations.Add(location);
            device.LastSyncAt = now;
            if (dto.NotifyParents)
            {
                var parentIds = await _context.ParentChildren.AsNoTracking()
                    .Where(pc => pc.ChildId == child.Id && pc.IsActive && pc.Parent.IsActive)
                    .Select(pc => pc.ParentId).Distinct().ToListAsync();
                var address = string.IsNullOrWhiteSpace(dto.Address)
                    ? $"Tọa độ {dto.Latitude.Value:F6}, {dto.Longitude.Value:F6} (chưa tra được địa chỉ)"
                    : dto.Address.Trim();
                var text = $"{child.FullName} đã gửi vị trí: {address}. Ghi nhận {recordedAt:HH:mm dd/MM/yyyy} UTC. Mở bản đồ để xem vị trí.";
                foreach (var parentId in parentIds)
                    _context.Notifications.Add(new Notification {
                        UserId = parentId, Title = "Con đã chia sẻ vị trí", Type = "LOCATION_SHARED",
                        Message = text.Length > 500 ? text[..500] : text,
                        ReferenceId = child.Id, CreatedAt = now
                    });
            }
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = dto.NotifyParents ? "Đã gửi vị trí và thông báo cho phụ huynh." : "Đã cập nhật vị trí.",
                address = dto.Address,
                location = new
                {
                    location.Id,
                    location.DeviceId,
                    location.Latitude,
                    location.Longitude,
                    location.AccuracyMeters,
                    location.RecordedAt,
                    location.ReceivedAt,
                    location.Source,
                    location.Address
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
                    l.Source,
                    l.Address
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
                    l.Source,
                    l.Address
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
