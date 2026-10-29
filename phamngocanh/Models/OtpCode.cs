
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class OtpCode
    {
        [Key]
        public long Id { get; set; }

        [Required]
        public string UserId { get; set; } = string.Empty;

        [ForeignKey(nameof(UserId))]
        public ApplicationUser User { get; set; } = null!;

        [Required]
        [MaxLength(128)]
        public string CodeHash { get; set; } = string.Empty;

        [Required]
        [MaxLength(30)]
        public string Purpose { get; set; } = "LOGIN";

        public DateTime ExpiresAt { get; set; }

        public DateTime? UsedAt { get; set; }

        [Range(0, 5)]
        public int AttemptCount { get; set; } = 0;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
