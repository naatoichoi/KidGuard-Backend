
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
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
    [Authorize(Roles = "Parent")]
    public class ChildrenController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;

        public ChildrenController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager,
            RoleManager<IdentityRole> roleManager)
        {
            _context = context;
            _userManager = userManager;
            _roleManager = roleManager;
        }

        // POST: api/Children
        [HttpPost]
        public async Task<IActionResult> CreateChild(
            [FromBody] CreateChildDto dto)
        {
            string? parentId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(parentId))
            {
                return Unauthorized(new
                {
                    message = "Không xác định được tài khoản Parent."
                });
            }

            var parent = await _userManager.FindByIdAsync(parentId);

            if (parent == null || !parent.IsActive)
            {
                return Unauthorized(new
                {
                    message = "Tài khoản Parent không hợp lệ."
                });
            }

            string userName = dto.UserName.Trim();
            string fullName = dto.FullName.Trim();

            if (string.IsNullOrWhiteSpace(userName) ||
                string.IsNullOrWhiteSpace(fullName))
            {
                return BadRequest(new
                {
                    message = "Họ tên và tên đăng nhập không được để trống."
                });
            }

            if (await _userManager.FindByNameAsync(userName) != null)
            {
                return Conflict(new
                {
                    message = "Tên đăng nhập Child đã tồn tại."
                });
            }

            if (dto.DateOfBirth.HasValue &&
                dto.DateOfBirth.Value.Date > DateTime.UtcNow.Date)
            {
                return BadRequest(new
                {
                    message = "Ngày sinh không được lớn hơn ngày hiện tại."
                });
            }

            // Đảm bảo Role Child tồn tại
            if (!await _roleManager.RoleExistsAsync("Child"))
            {
                var roleResult = await _roleManager.CreateAsync(
                    new IdentityRole("Child"));

                if (!roleResult.Succeeded)
                {
                    return StatusCode(500, new
                    {
                        message = "Không thể khởi tạo quyền Child."
                    });
                }
            }

            // Tạo tài khoản đăng nhập cho Child
            // Email của Parent dùng để nhận OTP,
            // không gán vào Child vì Identity yêu cầu email duy nhất.
            var childUser = new ApplicationUser
            {
                UserName = userName,
                FullName = fullName,
                Email = null,
                EmailConfirmed = false,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            // Dùng transaction để tránh tạo tài khoản
            // mà thiếu thông tin Child hoặc ParentChild.
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            var createResult = await _userManager.CreateAsync(
                childUser, dto.Password);

            if (!createResult.Succeeded)
            {
                await transaction.RollbackAsync();

                return BadRequest(new
                {
                    message = "Không thể tạo tài khoản Child.",
                    errors = createResult.Errors
                        .Select(e => e.Description)
                });
            }

            var addRoleResult = await _userManager.AddToRoleAsync(
                childUser, "Child");

            if (!addRoleResult.Succeeded)
            {
                await transaction.RollbackAsync();

                return StatusCode(500, new
                {
                    message = "Không thể gán quyền Child."
                });
            }

            var child = new Child
            {
                UserId = childUser.Id,
                FullName = fullName,
                DateOfBirth = dto.DateOfBirth?.Date,
                OtpRecipientParentId = parentId,
                CreatedAt = DateTime.UtcNow,
                IsActive = true
            };

            _context.Children.Add(child);
            await _context.SaveChangesAsync();

            var parentChild = new ParentChild
            {
                ParentId = parentId,
                ChildId = child.Id,
                Relationship = "Guardian",
                LinkedAt = DateTime.UtcNow,
                IsActive = true
            };

            _context.ParentChildren.Add(parentChild);
            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            return StatusCode(201, new
            {
                message = "Tạo tài khoản Child thành công.",
                child = new
                {
                    id = child.Id,
                    userId = childUser.Id,
                    userName = childUser.UserName,
                    fullName = child.FullName,
                    dateOfBirth = child.DateOfBirth,
                    parentId = parentId,
                    otpRecipientEmail = parent.Email
                }
            });
        }

        // GET: api/Children
        [HttpGet]
        public async Task<IActionResult> GetMyChildren()
        {
            string? parentId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(parentId))
            {
                return Unauthorized();
            }

            var children = await _context.ParentChildren
                .AsNoTracking()
                .Where(pc =>
                    pc.ParentId == parentId &&
                    pc.IsActive &&
                    pc.Child.IsActive)
                .Select(pc => new
                {
                    id = pc.Child.Id,
                    userId = pc.Child.UserId,
                    userName = pc.Child.User.UserName,
                    fullName = pc.Child.FullName,
                    dateOfBirth = pc.Child.DateOfBirth,
                    relationship = pc.Relationship,
                    linkedAt = pc.LinkedAt
                })
                .ToListAsync();

            return Ok(children);
        }
    }
}
