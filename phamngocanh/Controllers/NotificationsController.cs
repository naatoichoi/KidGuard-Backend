
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
    [Authorize(Roles = "Parent,Child")]
    public class NotificationsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public NotificationsController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        // GET: api/Notifications
        // Lấy danh sách thông báo của tài khoản đang đăng nhập
        [HttpGet]
        public async Task<IActionResult> GetNotifications()
        {
            string? userId = _userManager.GetUserId(User);

            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized();
            }

            var notifications = await _context.Notifications
                .AsNoTracking()
                .Where(n => n.UserId == userId)
                .OrderByDescending(n => n.CreatedAt)
                .Select(n => new
                {
                    n.Id,
                    n.Title,
                    n.Message,
                    n.Type,
                    n.ReferenceId,
                    n.IsRead,
                    n.CreatedAt,
                    n.ReadAt
                })
                .ToListAsync();

            int unreadCount = notifications.Count(n => !n.IsRead);

            return Ok(new
            {
                totalCount = notifications.Count,
                unreadCount,
                notifications
            });
        }

        // PUT: api/Notifications/1/read
        // Đánh dấu một thông báo đã đọc
        [HttpPut("{id:long}/read")]
        public async Task<IActionResult> MarkAsRead(long id)
        {
            string? userId = _userManager.GetUserId(User);

            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized();
            }

            var notification = await _context.Notifications
                .FirstOrDefaultAsync(n =>
                    n.Id == id &&
                    n.UserId == userId);

            if (notification == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thông báo."
                });
            }

            if (!notification.IsRead)
            {
                notification.IsRead = true;
                notification.ReadAt = DateTime.UtcNow;

                await _context.SaveChangesAsync();
            }

            return Ok(new
            {
                message = "Đã đánh dấu thông báo là đã đọc.",
                notification.Id,
                notification.IsRead,
                notification.ReadAt
            });
        }

        // PUT: api/Notifications/read-all
        // Đánh dấu tất cả thông báo đã đọc
        [HttpPut("read-all")]
        public async Task<IActionResult> MarkAllAsRead()
        {
            string? userId = _userManager.GetUserId(User);

            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized();
            }

            var unreadNotifications = await _context.Notifications
                .Where(n =>
                    n.UserId == userId &&
                    !n.IsRead)
                .ToListAsync();

            DateTime now = DateTime.UtcNow;

            foreach (var notification in unreadNotifications)
            {
                notification.IsRead = true;
                notification.ReadAt = now;
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Đã đánh dấu tất cả thông báo là đã đọc.",
                updatedCount = unreadNotifications.Count
            });
        }
    }
}
