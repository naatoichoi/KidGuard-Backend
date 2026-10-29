
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class CreatePairingCodeDto
    {
        [Required]
        [MaxLength(100)]
        public string DeviceIdentifier { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string DeviceName { get; set; } = string.Empty;

        [MaxLength(30)]
        public string? AndroidVersion { get; set; }

        [Required]
        [RegularExpression(@"^[0-9A-Fa-f]{64}$")]
        public string DeviceSecret { get; set; } = string.Empty;
    }
}
