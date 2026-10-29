
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class LoginDto
    {
        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập.")]
        public string UserName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu.")]
        public string Password { get; set; } = string.Empty;
    }
}
