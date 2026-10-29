
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class Child
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string UserId { get; set; } = string.Empty;

        [ForeignKey(nameof(UserId))]
        public ApplicationUser User { get; set; } = null!;

        [Required]
        [MaxLength(100)]
        public string FullName { get; set; } = string.Empty;

        [Column(TypeName = "date")]
        public DateTime? DateOfBirth { get; set; }

        [Required]
        public string OtpRecipientParentId { get; set; } = string.Empty;

        [ForeignKey(nameof(OtpRecipientParentId))]
        public ApplicationUser OtpRecipientParent { get; set; } = null!;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public bool IsActive { get; set; } = true;
    }
}
