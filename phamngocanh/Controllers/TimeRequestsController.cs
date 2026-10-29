
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
    public class TimeRequestsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public TimeRequestsController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        // POST: api/TimeRequests
        // Child gửi yêu cầu xin thêm thời gian
        [HttpPost]
        [Authorize(Roles = "Child")]
        public async Task<IActionResult> CreateRequest(
            [FromBody] CreateTimeRequestDto dto)
        {
            string? userId = _userManager.GetUserId(User);

            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized();
            }

            var child = await _context.Children
                .AsNoTracking()
                .FirstOrDefaultAsync(c =>
                    c.UserId == userId &&
                    c.IsActive);

            if (child == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy hồ sơ Child."
                });
            }

            var device = await _context.Devices
                .AsNoTracking()
                .FirstOrDefaultAsync(d =>
                    d.Id == dto.DeviceId &&
                    d.ChildId == child.Id &&
                    d.IsActive);

            if (device == null)
            {
                return BadRequest(new
                {
                    message = "Thiết bị không thuộc Child này."
                });
            }

            var limit = await _context.ScreenTimeLimits
                .AsNoTracking()
                .FirstOrDefaultAsync(l =>
                    l.Id == dto.ScreenTimeLimitId &&
                    l.DeviceId == device.Id &&
                    l.IsEnabled);

            if (limit == null)
            {
                return BadRequest(new
                {
                    message = "Giới hạn thời gian không hợp lệ."
                });
            }

            bool hasPendingRequest = await _context.TimeRequests
                .AnyAsync(r =>
                    r.ChildId == child.Id &&
                    r.DeviceId == device.Id &&
                    r.ScreenTimeLimitId == limit.Id &&
                    r.Status == "PENDING");

            if (hasPendingRequest)
            {
                return Conflict(new
                {
                    message = "Đã có yêu cầu đang chờ duyệt cho giới hạn này."
                });
            }

            var parentIds = await _context.ParentChildren
                .AsNoTracking()
                .Where(pc =>
                    pc.ChildId == child.Id &&
                    pc.IsActive)
                .Select(pc => pc.ParentId)
                .Distinct()
                .ToListAsync();

            if (parentIds.Count == 0)
            {
                return BadRequest(new
                {
                    message = "Child chưa có Parent quản lý."
                });
            }

            DateTime now = DateTime.UtcNow;

            var request = new TimeRequest
            {
                ChildId = child.Id,
                DeviceId = device.Id,
                ScreenTimeLimitId = limit.Id,
                RequestedMinutes = dto.RequestedMinutes,
                Reason = string.IsNullOrWhiteSpace(dto.Reason)
                    ? null
                    : dto.Reason.Trim(),
                Status = "PENDING",
                CreatedAt = now
            };

            _context.TimeRequests.Add(request);

            await _context.SaveChangesAsync();

            foreach (string parentId in parentIds)
            {
                _context.Notifications.Add(new Notification
                {
                    UserId = parentId,
                    Title = "Yêu cầu thêm thời gian",
                    Message =
                        $"{child.FullName} xin thêm " +
                        $"{request.RequestedMinutes} phút sử dụng. " +
                        $"Lý do: {request.Reason ?? "Không có"}.",
                    Type = "TIME_REQUEST",
                    ReferenceId = request.Id,
                    IsRead = false,
                    CreatedAt = now
                });
            }

            await _context.SaveChangesAsync();

            return StatusCode(201, new
            {
                message = "Gửi yêu cầu thêm thời gian thành công.",
                request = new
                {
                    request.Id,
                    request.ChildId,
                    request.DeviceId,
                    request.ScreenTimeLimitId,
                    request.RequestedMinutes,
                    request.Reason,
                    request.Status,
                    request.CreatedAt
                }
            });
        }

        // GET: api/TimeRequests/pending
        // Parent xem yêu cầu đang chờ duyệt
        [HttpGet("pending")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> GetPendingRequests()
        {
            string? parentId = _userManager.GetUserId(User);

            if (string.IsNullOrWhiteSpace(parentId))
            {
                return Unauthorized();
            }

            var requests = await _context.TimeRequests
                .AsNoTracking()
                .Where(r =>
                    r.Status == "PENDING" &&
                    _context.ParentChildren.Any(pc =>
                        pc.ChildId == r.ChildId &&
                        pc.ParentId == parentId &&
                        pc.IsActive &&
                        pc.Child.IsActive))
                .OrderByDescending(r => r.CreatedAt)
                .Select(r => new
                {
                    r.Id,
                    r.ChildId,
                    childName = r.Child.FullName,
                    r.DeviceId,
                    deviceName = r.Device.DeviceName,
                    r.ScreenTimeLimitId,
                    limitType = r.ScreenTimeLimit.LimitType,
                    packageName = r.ScreenTimeLimit.PackageName,
                    dailyLimitMinutes =
                        r.ScreenTimeLimit.DailyLimitMinutes,
                    r.RequestedMinutes,
                    r.Reason,
                    r.Status,
                    r.CreatedAt
                })
                .ToListAsync();

            return Ok(new
            {
                totalCount = requests.Count,
                requests
            });
        }

        // PUT: api/TimeRequests/1/approve
        // Parent phê duyệt yêu cầu
        [HttpPut("{id:int}/approve")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> ApproveRequest(int id)
        {
            string? parentId = _userManager.GetUserId(User);

            if (string.IsNullOrWhiteSpace(parentId))
            {
                return Unauthorized();
            }

            var request = await _context.TimeRequests
                .Include(r => r.Child)
                .Include(r => r.Device)
                .Include(r => r.ScreenTimeLimit)
                .FirstOrDefaultAsync(r => r.Id == id);

            if (request == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy yêu cầu."
                });
            }

            bool hasAccess = await _context.ParentChildren
                .AnyAsync(pc =>
                    pc.ParentId == parentId &&
                    pc.ChildId == request.ChildId &&
                    pc.IsActive &&
                    pc.Child.IsActive);

            if (!hasAccess)
            {
                return StatusCode(403, new
                {
                    message = "Bạn không có quyền duyệt yêu cầu này."
                });
            }

            if (request.Status != "PENDING")
            {
                return Conflict(new
                {
                    message = "Yêu cầu đã được xử lý trước đó."
                });
            }

            if (!request.Device.IsActive ||
                request.Device.ChildId != request.ChildId ||
                !request.ScreenTimeLimit.IsEnabled ||
                request.ScreenTimeLimit.DeviceId != request.DeviceId)
            {
                return BadRequest(new
                {
                    message = "Thiết bị hoặc giới hạn không còn hợp lệ."
                });
            }

            DateTime now = DateTime.UtcNow;
            DateTime effectiveDate = now.Date;

            // Chỉ cộng thời gian cho ngày được duyệt.
            // Không sửa DailyLimitMinutes mặc định.
            var extension = new TimeExtension
            {
                TimeRequestId = request.Id,
                ScreenTimeLimitId = request.ScreenTimeLimitId,
                ExtraMinutes = request.RequestedMinutes,
                EffectiveDate = effectiveDate,
                CreatedAt = now
            };

            request.Status = "APPROVED";
            request.ReviewedBy = parentId;
            request.ReviewedAt = now;

            _context.TimeExtensions.Add(extension);

            _context.Notifications.Add(new Notification
            {
                UserId = request.Child.UserId,
                Title = "Yêu cầu đã được phê duyệt",
                Message =
                    $"Parent đã đồng ý cho con thêm " +
                    $"{request.RequestedMinutes} phút sử dụng " +
                    $"trong ngày {effectiveDate:yyyy-MM-dd}.",
                Type = "TIME_REQUEST_APPROVED",
                ReferenceId = request.Id,
                IsRead = false,
                CreatedAt = now
            });

            await _context.SaveChangesAsync();

            int totalExtraMinutes = await _context.TimeExtensions
                .Where(e =>
                    e.ScreenTimeLimitId == request.ScreenTimeLimitId &&
                    e.EffectiveDate == effectiveDate)
                .SumAsync(e => (int?)e.ExtraMinutes) ?? 0;

            return Ok(new
            {
                message = "Phê duyệt yêu cầu thành công.",
                requestId = request.Id,
                status = request.Status,
                approvedMinutes = request.RequestedMinutes,
                effectiveDate = effectiveDate.ToString("yyyy-MM-dd"),
                baseLimitMinutes =
                    request.ScreenTimeLimit.DailyLimitMinutes,
                totalExtraMinutes,
                effectiveLimitMinutes =
                    request.ScreenTimeLimit.DailyLimitMinutes +
                    totalExtraMinutes,
                reviewedAt = request.ReviewedAt
            });
        }

        // PUT: api/TimeRequests/1/reject
        // Parent từ chối yêu cầu
        [HttpPut("{id:int}/reject")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> RejectRequest(int id)
        {
            string? parentId = _userManager.GetUserId(User);

            if (string.IsNullOrWhiteSpace(parentId))
            {
                return Unauthorized();
            }

            var request = await _context.TimeRequests
                .Include(r => r.Child)
                .FirstOrDefaultAsync(r => r.Id == id);

            if (request == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy yêu cầu."
                });
            }

            bool hasAccess = await _context.ParentChildren
                .AnyAsync(pc =>
                    pc.ParentId == parentId &&
                    pc.ChildId == request.ChildId &&
                    pc.IsActive &&
                    pc.Child.IsActive);

            if (!hasAccess)
            {
                return StatusCode(403, new
                {
                    message = "Bạn không có quyền từ chối yêu cầu này."
                });
            }

            if (request.Status != "PENDING")
            {
                return Conflict(new
                {
                    message = "Yêu cầu đã được xử lý trước đó."
                });
            }

            DateTime now = DateTime.UtcNow;

            request.Status = "REJECTED";
            request.ReviewedBy = parentId;
            request.ReviewedAt = now;

            _context.Notifications.Add(new Notification
            {
                UserId = request.Child.UserId,
                Title = "Yêu cầu thêm thời gian bị từ chối",
                Message =
                    $"Parent đã từ chối yêu cầu thêm " +
                    $"{request.RequestedMinutes} phút sử dụng.",
                Type = "TIME_REQUEST_REJECTED",
                ReferenceId = request.Id,
                IsRead = false,
                CreatedAt = now
            });

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Đã từ chối yêu cầu.",
                requestId = request.Id,
                status = request.Status,
                reviewedAt = request.ReviewedAt
            });
        }

        // GET: api/TimeRequests/history?page=1&pageSize=20&status=APPROVED
        // Parent xem lịch sử yêu cầu của những Child mình quản lý.
        [HttpGet("history")]
        [Authorize(Roles = "Parent")]
        public async Task<IActionResult> GetHistory(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? status = null,
            [FromQuery] int? childId = null)
        {
            string? parentId = _userManager.GetUserId(User);
            if (string.IsNullOrWhiteSpace(parentId)) return Unauthorized();

            if (page < 1 || pageSize < 1 || pageSize > 100)
                return BadRequest(new { message = "page phải >= 1; pageSize từ 1 đến 100." });

            string? normalizedStatus = status?.Trim().ToUpperInvariant();
            if (!string.IsNullOrEmpty(normalizedStatus) &&
                normalizedStatus != "PENDING" &&
                normalizedStatus != "APPROVED" &&
                normalizedStatus != "REJECTED")
                return BadRequest(new { message = "status phải là PENDING, APPROVED hoặc REJECTED." });

            if (childId.HasValue && childId.Value < 1)
                return BadRequest(new { message = "childId không hợp lệ." });

            var query = _context.TimeRequests.AsNoTracking()
                .Where(r => _context.ParentChildren.Any(pc =>
                    pc.ParentId == parentId &&
                    pc.ChildId == r.ChildId &&
                    pc.IsActive && pc.Child.IsActive));

            if (childId.HasValue)
                query = query.Where(r => r.ChildId == childId.Value);
            if (!string.IsNullOrEmpty(normalizedStatus))
                query = query.Where(r => r.Status == normalizedStatus);

            int totalCount = await query.CountAsync();
            var requests = await query
                .OrderByDescending(r => r.CreatedAt)
                .ThenByDescending(r => r.Id)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(r => new
                {
                    r.Id,
                    r.ChildId,
                    childName = r.Child.FullName,
                    r.DeviceId,
                    deviceName = r.Device.DeviceName,
                    r.ScreenTimeLimitId,
                    limitType = r.ScreenTimeLimit.LimitType,
                    packageName = r.ScreenTimeLimit.PackageName,
                    r.RequestedMinutes,
                    r.Reason,
                    r.Status,
                    r.CreatedAt,
                    r.ReviewedAt
                })
                .ToListAsync();

            return Ok(new { totalCount, page, pageSize, requests });
        }

        // GET: api/TimeRequests/my?page=1&pageSize=20
        // Child xem các yêu cầu do chính mình gửi.
        [HttpGet("my")]
        [Authorize(Roles = "Child")]
        public async Task<IActionResult> GetMyRequests(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            string? userId = _userManager.GetUserId(User);
            if (string.IsNullOrWhiteSpace(userId)) return Unauthorized();

            if (page < 1 || pageSize < 1 || pageSize > 100)
                return BadRequest(new { message = "page phải >= 1; pageSize từ 1 đến 100." });

            var childId = await _context.Children.AsNoTracking()
                .Where(c => c.UserId == userId && c.IsActive)
                .Select(c => (int?)c.Id)
                .FirstOrDefaultAsync();
            if (!childId.HasValue)
                return NotFound(new { message = "Không tìm thấy hồ sơ Child." });

            var query = _context.TimeRequests.AsNoTracking()
                .Where(r => r.ChildId == childId.Value);

            int totalCount = await query.CountAsync();
            var requests = await query
                .OrderByDescending(r => r.CreatedAt)
                .ThenByDescending(r => r.Id)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(r => new
                {
                    r.Id,
                    r.DeviceId,
                    deviceName = r.Device.DeviceName,
                    r.ScreenTimeLimitId,
                    limitType = r.ScreenTimeLimit.LimitType,
                    packageName = r.ScreenTimeLimit.PackageName,
                    r.RequestedMinutes,
                    r.Reason,
                    r.Status,
                    r.CreatedAt,
                    r.ReviewedAt
                })
                .ToListAsync();

            return Ok(new { childId, totalCount, page, pageSize, requests });
        }
    }
}
