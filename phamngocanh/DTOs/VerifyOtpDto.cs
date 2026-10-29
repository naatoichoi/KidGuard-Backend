
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class VerifyOtpDto
    {
        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập.")]
        public string UserName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập mã OTP.")]
        [RegularExpression(@"^\d{6}$",
            ErrorMessage = "Mã OTP phải gồm đúng 6 chữ số.")]
        public string Code { get; set; } = string.Empty;
    }
}
