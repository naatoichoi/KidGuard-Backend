using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Data;

namespace phamngocanh.Controllers;

[ApiController]
[Route("api/DeviceApps")]
[Authorize(Roles = "Parent")]
public class DeviceAppsController(ApplicationDbContext context) : ControllerBase
{
    [HttpGet("{deviceId:int}")]
    public async Task<IActionResult> GetApps(int deviceId)
    {
        var parentId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(parentId)) return Unauthorized();
        var device = await context.Devices.AsNoTracking().FirstOrDefaultAsync(d => d.Id == deviceId && d.IsActive);
        if (device == null) return NotFound();
        if (!await context.ParentChildren.AnyAsync(pc => pc.ParentId == parentId &&
            pc.ChildId == device.ChildId && pc.IsActive && pc.Child.IsActive)) return Forbid();

        // Each sync is a complete catalog including zero-minute launchable apps.
        // Preserve the latest inventory when the child has not synced today.
        var inventoryDate = await context.AppUsages.Where(a => a.DeviceId == deviceId)
            .OrderByDescending(a => a.UsageDate).Select(a => (DateTime?)a.UsageDate).FirstOrDefaultAsync();
        var today = DateTime.UtcNow.Date;
        var records = await context.AppUsages.AsNoTracking()
            .Where(a => a.DeviceId == deviceId && a.UsageDate == inventoryDate)
            .OrderBy(a => a.AppName).ToListAsync();
        return Ok(new {
            deviceId, usageDate = today.ToString("yyyy-MM-dd"),
            inventoryDate = inventoryDate?.ToString("yyyy-MM-dd"),
            lastSyncAt = records.Select(a => (DateTime?)a.LastSyncedAt).Max(),
            apps = records.Select(a => new {
                a.PackageName, a.AppName,
                durationSeconds = inventoryDate == today ? a.DurationSeconds : 0,
                durationMinutes = inventoryDate == today ? Math.Round(a.DurationSeconds / 60.0, 2) : 0
            }).ToList()
        });
    }
}
