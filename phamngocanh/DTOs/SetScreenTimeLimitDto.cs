
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class SetScreenTimeLimitDto
    {
        [Required]
        [Range(1, int.MaxValue)]
        public int DeviceId { get; set; }

        [Required]
        [RegularExpression("^(TOTAL|APP)$",
            ErrorMessage = "LimitType phải là TOTAL hoặc APP.")]
        public string LimitType { get; set; } = "TOTAL";

        [MaxLength(255)]
        public string? PackageName { get; set; }

        [Required]
        [Range(1, 1440,
            ErrorMessage = "Giới hạn phải từ 1 đến 1440 phút.")]
        public int DailyLimitMinutes { get; set; }

        public bool IsEnabled { get; set; } = true;
    }
}
