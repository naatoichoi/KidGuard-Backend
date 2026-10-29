
using System.ComponentModel.DataAnnotations;

namespace phamngocanh.DTOs
{
    public class SyncAppUsageDto
    {
        [Required(ErrorMessage = "Vui lòng cung cấp ID thiết bị.")]
        [Range(1, int.MaxValue, ErrorMessage = "ID thiết bị không hợp lệ.")]
        public int DeviceId { get; set; }

        [Required(ErrorMessage = "Vui lòng cung cấp ngày sử dụng.")]
        public DateTime UsageDate { get; set; }

        [Required(ErrorMessage = "Vui lòng cung cấp danh sách ứng dụng.")]
        [MinLength(1, ErrorMessage = "Danh sách ứng dụng không được rỗng.")]
        public List<AppUsageItemDto> Apps { get; set; } = new();
    }

    public class AppUsageItemDto
    {
        [Required(ErrorMessage = "Package name không được để trống.")]
        [MaxLength(255)]
        public string PackageName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Tên ứng dụng không được để trống.")]
        [MaxLength(150)]
        public string AppName { get; set; } = string.Empty;

        [Range(0, long.MaxValue,
            ErrorMessage = "Thời gian sử dụng không được âm.")]
        public long DurationSeconds { get; set; }
    }
}
