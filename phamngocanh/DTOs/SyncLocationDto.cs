
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class SyncLocationDto
    {
        [Required]
        [Range(1, int.MaxValue)]
        public int DeviceId { get; set; }

        [Required]
        [Range(-90.0, 90.0)]
        public decimal? Latitude { get; set; }

        [Required]
        [Range(-180.0, 180.0)]
        public decimal? Longitude { get; set; }

        [Range(0, double.MaxValue)]
        public double? AccuracyMeters { get; set; }

        [Required]
        public DateTime? RecordedAt { get; set; }

        [Required]
        [MaxLength(20)]
        public string Source { get; set; } = "FUSED";
    }
}
