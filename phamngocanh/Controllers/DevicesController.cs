
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;
using System.Security.Claims;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = "Parent")]
    public class DevicesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public DevicesController(ApplicationDbContext context)
        {
            _context = context;
        }

        // GET: api/Devices/child/1
        [HttpGet("child/{childId:int}")]
        public async Task<IActionResult> GetChildDevices(int childId)
        {
            string? parentId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(parentId))
            {
                return Unauthorized();
            }

            bool canManageChild = await _context.ParentChildren
                .AnyAsync(pc =>
                    pc.ParentId == parentId &&
                    pc.ChildId == childId &&
                    pc.IsActive &&
                    pc.Child.IsActive);

            if (!canManageChild)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy Child thuộc quyền quản lý."
                });
            }

            var devices = await _context.Devices
                .AsNoTracking()
                .Where(d => d.ChildId == childId)
                .OrderByDescending(d => d.CreatedAt)
                .Select(d => new
                {
                    id = d.Id,
                    childId = d.ChildId,
                    deviceName = d.DeviceName,
                    deviceIdentifier = d.DeviceIdentifier,
                    platform = d.Platform,
                    androidVersion = d.AndroidVersion,
                    isActive = d.IsActive,
                    lastSyncAt = d.LastSyncAt,
                    createdAt = d.CreatedAt
                })
                .ToListAsync();

            return Ok(devices);
        }
    }
}
