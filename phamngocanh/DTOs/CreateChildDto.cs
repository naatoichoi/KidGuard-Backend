
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class CreateChildDto
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên trẻ.")]
        [StringLength(100)]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập.")]
        [StringLength(50, MinimumLength = 3)]
        public string UserName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu.")]
        [StringLength(100, MinimumLength = 6)]
        public string Password { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng xác nhận mật khẩu.")]
        [Compare(nameof(Password),
            ErrorMessage = "Mật khẩu xác nhận không khớp.")]
        public string ConfirmPassword { get; set; } = string.Empty;

        [DataType(DataType.Date)]
        public DateTime? DateOfBirth { get; set; }
    }
}
