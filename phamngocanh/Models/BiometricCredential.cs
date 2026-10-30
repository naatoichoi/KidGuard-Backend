using System.ComponentModel.DataAnnotations;

namespace phamngocanh.Models
{
    public class BiometricCredential
    {
        public int Id { get; set; }

        [Required]
        [MaxLength(450)]
        public string UserId { get; set; } = string.Empty;

        [Required]
        [MaxLength(64)]
        public string DeviceId { get; set; } = string.Empty;

        [Required]
        [MaxLength(64)]
        public string SecretHash { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? LastUsedAt { get; set; }

        public ApplicationUser User { get; set; } = null!;
    }
}
