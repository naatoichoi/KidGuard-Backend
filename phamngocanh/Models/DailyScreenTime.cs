
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class DailyScreenTime
    {
        [Key]
        public long Id { get; set; }

        [Required]
        public int DeviceId { get; set; }

        [ForeignKey(nameof(DeviceId))]
        public Device Device { get; set; } = null!;

        [Required]
        [Column(TypeName = "date")]
        public DateTime UsageDate { get; set; }

        [Range(0, long.MaxValue)]
        public long TotalSeconds { get; set; }

        public DateTime LastSyncedAt { get; set; } = DateTime.UtcNow;
    }
}
