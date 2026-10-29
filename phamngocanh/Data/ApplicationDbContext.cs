
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using phamngocanh.Models;

namespace phamngocanh.Data
{
    public class ApplicationDbContext
        : IdentityDbContext<ApplicationUser>
    {
        public ApplicationDbContext(
            DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<Child> Children => Set<Child>();
        public DbSet<ParentChild> ParentChildren => Set<ParentChild>();
        public DbSet<Device> Devices => Set<Device>();
        public DbSet<PairingCode> PairingCodes => Set<PairingCode>();

        public DbSet<AppUsage> AppUsages => Set<AppUsage>();
        public DbSet<DailyScreenTime> DailyScreenTimes => Set<DailyScreenTime>();
        public DbSet<ScreenTimeLimit> ScreenTimeLimits => Set<ScreenTimeLimit>();
        public DbSet<TimeRequest> TimeRequests => Set<TimeRequest>();
        public DbSet<TimeExtension> TimeExtensions => Set<TimeExtension>();

        public DbSet<Location> Locations => Set<Location>();
        public DbSet<Notification> Notifications => Set<Notification>();

        public DbSet<OtpCode> OtpCodes => Set<OtpCode>();
        public DbSet<DeviceSyncLog> DeviceSyncLogs => Set<DeviceSyncLog>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // CHILDREN
            modelBuilder.Entity<Child>(entity =>
            {
                entity.HasIndex(x => x.UserId).IsUnique();

                entity.HasOne(x => x.User)
                    .WithMany()
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.OtpRecipientParent)
                    .WithMany()
                    .HasForeignKey(x => x.OtpRecipientParentId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // PARENT - CHILD
            modelBuilder.Entity<ParentChild>(entity =>
            {
                entity.HasIndex(x => new
                {
                    x.ParentId,
                    x.ChildId
                }).IsUnique();

                entity.HasOne(x => x.Parent)
                    .WithMany()
                    .HasForeignKey(x => x.ParentId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Child)
                    .WithMany()
                    .HasForeignKey(x => x.ChildId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // DEVICES
            modelBuilder.Entity<Device>(entity =>
            {
                entity.HasIndex(x => x.DeviceIdentifier)
                    .IsUnique();

                entity.HasOne(x => x.Child)
                    .WithMany()
                    .HasForeignKey(x => x.ChildId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // QR PAIRING
            modelBuilder.Entity<PairingCode>(entity =>
            {
                entity.HasIndex(x => x.SetupTokenHash)
                    .IsUnique();

                entity.HasOne(x => x.Child)
                    .WithMany()
                    .HasForeignKey(x => x.ChildId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Creator)
                    .WithMany()
                    .HasForeignKey(x => x.CreatedBy)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // APP USAGE
            modelBuilder.Entity<AppUsage>(entity =>
            {
                entity.HasIndex(x => new
                {
                    x.DeviceId,
                    x.PackageName,
                    x.UsageDate
                }).IsUnique();

                entity.HasOne(x => x.Device)
                    .WithMany()
                    .HasForeignKey(x => x.DeviceId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // DAILY SCREEN TIME
            modelBuilder.Entity<DailyScreenTime>(entity =>
            {
                entity.HasIndex(x => new
                {
                    x.DeviceId,
                    x.UsageDate
                }).IsUnique();

                entity.HasOne(x => x.Device)
                    .WithMany()
                    .HasForeignKey(x => x.DeviceId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // SCREEN TIME LIMITS
            modelBuilder.Entity<ScreenTimeLimit>(entity =>
            {
                entity.ToTable(t =>
                {
                    t.HasCheckConstraint(
                        "CK_ScreenTimeLimits_Type",
                        "[LimitType] IN ('TOTAL', 'APP')");

                    t.HasCheckConstraint(
                        "CK_ScreenTimeLimits_Package",
                        "([LimitType] = 'TOTAL' AND [PackageName] IS NULL) " +
                        "OR ([LimitType] = 'APP' AND " +
                        "[PackageName] IS NOT NULL AND LEN([PackageName]) > 0)");

                    t.HasCheckConstraint(
                        "CK_ScreenTimeLimits_Minutes",
                        "[DailyLimitMinutes] > 0");
                });

                entity.HasIndex(x => x.DeviceId)
                    .IsUnique()
                    .HasFilter("[LimitType] = 'TOTAL'");

                entity.HasIndex(x => new
                {
                    x.DeviceId,
                    x.PackageName
                })
                    .IsUnique()
                    .HasFilter("[LimitType] = 'APP'");

                entity.HasOne(x => x.Device)
                    .WithMany()
                    .HasForeignKey(x => x.DeviceId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // TIME REQUESTS
            modelBuilder.Entity<TimeRequest>(entity =>
            {
                entity.ToTable(t =>
                {
                    t.HasCheckConstraint(
                        "CK_TimeRequests_Status",
                        "[Status] IN ('PENDING', 'APPROVED', 'REJECTED')");

                    t.HasCheckConstraint(
                        "CK_TimeRequests_Minutes",
                        "[RequestedMinutes] > 0");
                });

                entity.HasOne(x => x.Child)
                    .WithMany()
                    .HasForeignKey(x => x.ChildId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Device)
                    .WithMany()
                    .HasForeignKey(x => x.DeviceId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.ScreenTimeLimit)
                    .WithMany()
                    .HasForeignKey(x => x.ScreenTimeLimitId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Reviewer)
                    .WithMany()
                    .HasForeignKey(x => x.ReviewedBy)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // TIME EXTENSIONS
            modelBuilder.Entity<TimeExtension>(entity =>
            {
                entity.HasIndex(x => x.TimeRequestId)
                    .IsUnique();

                entity.ToTable(t =>
                {
                    t.HasCheckConstraint(
                        "CK_TimeExtensions_Minutes",
                        "[ExtraMinutes] > 0");
                });

                entity.HasOne(x => x.TimeRequest)
                    .WithMany()
                    .HasForeignKey(x => x.TimeRequestId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.ScreenTimeLimit)
                    .WithMany()
                    .HasForeignKey(x => x.ScreenTimeLimitId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // LOCATIONS
            modelBuilder.Entity<Location>(entity =>
            {
                entity.HasIndex(x => new
                {
                    x.DeviceId,
                    x.RecordedAt
                });

                entity.HasOne(x => x.Device)
                    .WithMany()
                    .HasForeignKey(x => x.DeviceId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // NOTIFICATIONS
            modelBuilder.Entity<Notification>(entity =>
            {
                entity.HasIndex(x => new
                {
                    x.UserId,
                    x.IsRead
                });

                entity.HasOne(x => x.User)
                    .WithMany()
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // OTP CODES
            modelBuilder.Entity<OtpCode>(entity =>
            {
                entity.HasIndex(x => new
                {
                    x.UserId,
                    x.Purpose,
                    x.ExpiresAt
                });

                entity.HasOne(x => x.User)
                    .WithMany()
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // DEVICE SYNC LOGS
            modelBuilder.Entity<DeviceSyncLog>(entity =>
            {
                entity.HasIndex(x => new
                {
                    x.DeviceId,
                    x.StartedAt
                });

                entity.HasOne(x => x.Device)
                    .WithMany()
                    .HasForeignKey(x => x.DeviceId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }
    }
}
