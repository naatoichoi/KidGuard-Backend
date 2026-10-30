using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class LoginBiometricDto
    {
        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập.")]
        public string UserName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Thiếu mã thiết bị.")]
        [MaxLength(64)]
        public string DeviceId { get; set; } = string.Empty;

        [Required(ErrorMessage = "Thiếu khóa sinh trắc học.")]
        [MinLength(32)]
        [MaxLength(128)]
        public string Secret { get; set; } = string.Empty;
    }
}
