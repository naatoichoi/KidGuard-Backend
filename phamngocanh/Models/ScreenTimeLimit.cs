
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class ScreenTimeLimit
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int DeviceId { get; set; }

        [ForeignKey(nameof(DeviceId))]
        public Device Device { get; set; } = null!;

        [Required]
        [MaxLength(20)]
        public string LimitType { get; set; } = "TOTAL";

        [MaxLength(255)]
        public string? PackageName { get; set; }

        [Range(1, int.MaxValue)]
        public int DailyLimitMinutes { get; set; }

        public bool IsEnabled { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
