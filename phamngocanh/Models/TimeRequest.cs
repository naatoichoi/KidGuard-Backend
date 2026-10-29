
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class TimeRequest
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int ChildId { get; set; }

        [ForeignKey(nameof(ChildId))]
        public Child Child { get; set; } = null!;

        [Required]
        public int DeviceId { get; set; }

        [ForeignKey(nameof(DeviceId))]
        public Device Device { get; set; } = null!;

        [Required]
        public int ScreenTimeLimitId { get; set; }

        [ForeignKey(nameof(ScreenTimeLimitId))]
        public ScreenTimeLimit ScreenTimeLimit { get; set; } = null!;

        [Range(1, int.MaxValue)]
        public int RequestedMinutes { get; set; }

        [MaxLength(500)]
        public string? Reason { get; set; }

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "PENDING";

        public string? ReviewedBy { get; set; }

        [ForeignKey(nameof(ReviewedBy))]
        public ApplicationUser? Reviewer { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? ReviewedAt { get; set; }
    }
}
