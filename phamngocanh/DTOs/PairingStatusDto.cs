
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class PairingStatusDto
    {
        [Required]
        [RegularExpression(@"^[0-9A-Fa-f]{64}$")]
        public string QrData { get; set; } = string.Empty;

        [Required]
        [RegularExpression(@"^[0-9A-Fa-f]{64}$")]
        public string DeviceSecret { get; set; } = string.Empty;
    }
}
