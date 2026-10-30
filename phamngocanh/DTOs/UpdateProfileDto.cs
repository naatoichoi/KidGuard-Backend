using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class UpdateProfileDto
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên.")]
        [MaxLength(100)]
        public string FullName { get; set; } = string.Empty;

        [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
        [MaxLength(256)]
        public string? Email { get; set; }

        [MinLength(6)]
        public string? CurrentPassword { get; set; }

        [MinLength(6)]
        public string? NewPassword { get; set; }

        [Compare(nameof(NewPassword),
            ErrorMessage = "Mật khẩu xác nhận không khớp.")]
        public string? ConfirmPassword { get; set; }
    }
}
