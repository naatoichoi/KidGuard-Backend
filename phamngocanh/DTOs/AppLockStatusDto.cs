namespace phamngocanh.DTOs;

public sealed class AppLockStatusDto
{
    public int DeviceId { get; init; }
    public string PackageName { get; init; } = "";
    public string UsageDate { get; init; } = "";
    public bool ShouldBlock { get; init; }
    public string Action { get; init; } = "ALLOW_APP";
    public string Status { get; init; } = "NO_LIMIT";
    public int? LimitId { get; init; }
    public double? UsedMinutes { get; init; }
    public double? RemainingMinutes { get; init; }
    public long? EffectiveLimitMinutes { get; init; }
    public string Message { get; init; } = "";
    public string UsageSource { get; init; } = "LAST_SYNCED_USAGE";
    public DateTime EvaluatedAtUtc { get; init; } = DateTime.UtcNow;
}
