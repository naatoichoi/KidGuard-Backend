
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class Location
    {
        [Key]
        public long Id { get; set; }

        [Required]
        public int DeviceId { get; set; }

        [ForeignKey(nameof(DeviceId))]
        public Device Device { get; set; } = null!;

        [Required]
        [Column(TypeName = "decimal(10,7)")]
        [Range(-90.0, 90.0)]
        public decimal Latitude { get; set; }

        [Required]
        [Column(TypeName = "decimal(10,7)")]
        [Range(-180.0, 180.0)]
        public decimal Longitude { get; set; }

        public double? AccuracyMeters { get; set; }

        public DateTime RecordedAt { get; set; }

        public DateTime ReceivedAt { get; set; } = DateTime.UtcNow;

        [Required]
        [MaxLength(20)]
        public string Source { get; set; } = "FUSED";
    }
}
