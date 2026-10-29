
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class AppUsage
    {
        [Key]
        public long Id { get; set; }

        [Required]
        public int DeviceId { get; set; }

        [ForeignKey(nameof(DeviceId))]
        public Device Device { get; set; } = null!;

        [Required]
        [MaxLength(255)]
        public string PackageName { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        public string AppName { get; set; } = string.Empty;

        [Required]
        [Column(TypeName = "date")]
        public DateTime UsageDate { get; set; }

        [Range(0, long.MaxValue)]
        public long DurationSeconds { get; set; }

        public DateTime LastSyncedAt { get; set; } = DateTime.UtcNow;
    }
}
