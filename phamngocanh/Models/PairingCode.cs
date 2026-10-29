
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class PairingCode
    {
        [Key]
        public int Id { get; set; }

        public int? ChildId { get; set; }

        [ForeignKey(nameof(ChildId))]
        public Child? Child { get; set; }

        [Required]
        [MaxLength(128)]
        public string SetupTokenHash { get; set; } = string.Empty;

        [Required]
        [MaxLength(128)]
        public string DeviceSecretHash { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string DeviceIdentifier { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string DeviceName { get; set; } = string.Empty;

        [MaxLength(30)]
        public string? AndroidVersion { get; set; }

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "PENDING";

        public string? CreatedBy { get; set; }

        [ForeignKey(nameof(CreatedBy))]
        public ApplicationUser? Creator { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime ExpiresAt { get; set; }

        public DateTime? UsedAt { get; set; }

        public bool IsRevoked { get; set; } = false;
    }
}
