
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class ConfirmPairingDto
    {
        [Required(ErrorMessage = "Vui lòng cung cấp mã ghép nối.")]
        [RegularExpression(
            @"^[0-9A-Fa-f]{64}$",
            ErrorMessage = "Mã ghép nối không hợp lệ.")]
        public string QrData { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập tên trẻ em.")]
        [MaxLength(100, ErrorMessage = "Tên trẻ em tối đa 100 ký tự.")]
        public string ChildName { get; set; } = string.Empty;

        [Required]
        [StringLength(50, MinimumLength = 3)]
        [RegularExpression(@"^[a-zA-Z0-9._@+\-]+$")]
        public string UserName { get; set; } = string.Empty;

        [Required]
        [StringLength(100, MinimumLength = 6)]
        public string Password { get; set; } = string.Empty;

        [Required]
        [Compare(nameof(Password), ErrorMessage = "Mật khẩu xác nhận không khớp.")]
        public string ConfirmPassword { get; set; } = string.Empty;
    }
}
