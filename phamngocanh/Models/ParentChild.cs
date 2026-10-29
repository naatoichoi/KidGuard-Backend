
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace phamngocanh.Models
{
    public class ParentChild
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string ParentId { get; set; } = string.Empty;

        [ForeignKey(nameof(ParentId))]
        public ApplicationUser Parent { get; set; } = null!;

        [Required]
        public int ChildId { get; set; }

        [ForeignKey(nameof(ChildId))]
        public Child Child { get; set; } = null!;

        [Required]
        [MaxLength(30)]
        public string Relationship { get; set; } = "Guardian";

        public DateTime LinkedAt { get; set; } = DateTime.UtcNow;

        public bool IsActive { get; set; } = true;
    }
}
