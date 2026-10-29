
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
    }
}
