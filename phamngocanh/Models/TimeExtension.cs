
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class TimeExtension
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int TimeRequestId { get; set; }

        [ForeignKey(nameof(TimeRequestId))]
        public TimeRequest TimeRequest { get; set; } = null!;

        [Required]
        public int ScreenTimeLimitId { get; set; }

        [ForeignKey(nameof(ScreenTimeLimitId))]
        public ScreenTimeLimit ScreenTimeLimit { get; set; } = null!;

        [Range(1, int.MaxValue)]
        public int ExtraMinutes { get; set; }

        [Required]
        [Column(TypeName = "date")]
        public DateTime EffectiveDate { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
