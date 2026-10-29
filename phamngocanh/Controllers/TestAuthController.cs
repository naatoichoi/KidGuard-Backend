
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace phamngocanh.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TestAuthController : ControllerBase
    {
        [HttpGet("profile")]
        [Authorize]
        public IActionResult GetProfile()
        {
            return Ok(new
            {
                message = "JWT hợp lệ.",
                userId = User.FindFirstValue(
                    ClaimTypes.NameIdentifier),
                userName = User.Identity?.Name,
                roles = User.FindAll(ClaimTypes.Role)
                    .Select(c => c.Value)
                    .ToList()
            });
        }

        [HttpGet("parent-only")]
        [Authorize(Roles = "Parent")]
        public IActionResult ParentOnly()
        {
            return Ok(new
            {
                message = "Bạn có quyền Parent."
            });
        }

        [HttpGet("admin-only")]
        [Authorize(Roles = "Admin")]
        public IActionResult AdminOnly()
        {
            return Ok(new
            {
                message = "Bạn có quyền Admin."
            });
        }
    }
}
