
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class Device
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int ChildId { get; set; }

        [ForeignKey(nameof(ChildId))]
        public Child Child { get; set; } = null!;

        [Required]
        [MaxLength(100)]
        public string DeviceName { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string DeviceIdentifier { get; set; } = string.Empty;

        [Required]
        [MaxLength(128)]
        public string DeviceSecretHash { get; set; } = string.Empty;

        [Required]
        [MaxLength(20)]
        public string Platform { get; set; } = "Android";

        [MaxLength(30)]
        public string? AndroidVersion { get; set; }

        public DateTime? LastSyncAt { get; set; }

        public bool IsActive { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
