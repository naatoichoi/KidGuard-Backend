
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class CreateTimeRequestDto
    {
        [Required]
        [Range(1, int.MaxValue)]
        public int DeviceId { get; set; }

        [Required]
        [Range(1, int.MaxValue)]
        public int ScreenTimeLimitId { get; set; }

        [Required]
        [Range(1, 1440,
            ErrorMessage = "Số phút yêu cầu phải từ 1 đến 1440.")]
        public int RequestedMinutes { get; set; }

        [MaxLength(500)]
        public string? Reason { get; set; }
    }
}
