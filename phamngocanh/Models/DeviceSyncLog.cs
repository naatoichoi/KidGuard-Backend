
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class DeviceSyncLog
    {
        [Key]
        public long Id { get; set; }

        [Required]
        public int DeviceId { get; set; }

        [ForeignKey(nameof(DeviceId))]
        public Device Device { get; set; } = null!;

        [Required]
        [MaxLength(30)]
        public string SyncType { get; set; } = "FULL";

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "SUCCESS";

        public DateTime StartedAt { get; set; } = DateTime.UtcNow;

        public DateTime? CompletedAt { get; set; }

        [Range(0, int.MaxValue)]
        public int RecordsCount { get; set; } = 0;

        [MaxLength(500)]
        public string? ErrorMessage { get; set; }
    }
}
