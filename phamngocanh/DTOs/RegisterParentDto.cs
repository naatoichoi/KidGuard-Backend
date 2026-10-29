
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class RegisterParentDto
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên.")]
        [MaxLength(100)]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập.")]
        [MinLength(4)]
        [MaxLength(50)]
        public string UserName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập email.")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu.")]
        [MinLength(6)]
        public string Password { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng xác nhận mật khẩu.")]
        [Compare(nameof(Password),
            ErrorMessage = "Mật khẩu xác nhận không khớp.")]
        public string ConfirmPassword { get; set; } = string.Empty;
    }
}
