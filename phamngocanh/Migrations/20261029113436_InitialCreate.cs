using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace phamngocanh.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AspNetRoles",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    NormalizedName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AspNetRoles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AspNetUsers",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    UserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    NormalizedUserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    NormalizedEmail = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    EmailConfirmed = table.Column<bool>(type: "bit", nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    SecurityStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PhoneNumber = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PhoneNumberConfirmed = table.Column<bool>(type: "bit", nullable: false),
                    TwoFactorEnabled = table.Column<bool>(type: "bit", nullable: false),
                    LockoutEnd = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    LockoutEnabled = table.Column<bool>(type: "bit", nullable: false),
                    AccessFailedCount = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AspNetUsers", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AspNetRoleClaims",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    RoleId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AspNetRoleClaims", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AspNetRoleClaims_AspNetRoles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "AspNetRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AspNetUserClaims",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AspNetUserClaims", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AspNetUserClaims_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AspNetUserLogins",
                columns: table => new
                {
                    LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ProviderKey = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ProviderDisplayName = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AspNetUserLogins", x => new { x.LoginProvider, x.ProviderKey });
                    table.ForeignKey(
                        name: "FK_AspNetUserLogins_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AspNetUserRoles",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    RoleId = table.Column<string>(type: "nvarchar(450)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AspNetUserRoles", x => new { x.UserId, x.RoleId });
                    table.ForeignKey(
                        name: "FK_AspNetUserRoles_AspNetRoles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "AspNetRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_AspNetUserRoles_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AspNetUserTokens",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Value = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AspNetUserTokens", x => new { x.UserId, x.LoginProvider, x.Name });
                    table.ForeignKey(
                        name: "FK_AspNetUserTokens_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Children",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    DateOfBirth = table.Column<DateTime>(type: "date", nullable: true),
                    OtpRecipientParentId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Children", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Children_AspNetUsers_OtpRecipientParentId",
                        column: x => x.OtpRecipientParentId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Children_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Notifications",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Message = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Type = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    ReferenceId = table.Column<long>(type: "bigint", nullable: true),
                    IsRead = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReadAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Notifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Notifications_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "OtpCodes",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CodeHash = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Purpose = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UsedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    AttemptCount = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OtpCodes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_OtpCodes_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Devices",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ChildId = table.Column<int>(type: "int", nullable: false),
                    DeviceName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    DeviceIdentifier = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Platform = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    AndroidVersion = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    LastSyncAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Devices", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Devices_Children_ChildId",
                        column: x => x.ChildId,
                        principalTable: "Children",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PairingCodes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ChildId = table.Column<int>(type: "int", nullable: true),
                    SetupTokenHash = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    DeviceIdentifier = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    DeviceName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    AndroidVersion = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CreatedBy = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UsedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsRevoked = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PairingCodes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PairingCodes_AspNetUsers_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_PairingCodes_Children_ChildId",
                        column: x => x.ChildId,
                        principalTable: "Children",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ParentChildren",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ParentId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ChildId = table.Column<int>(type: "int", nullable: false),
                    Relationship = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    LinkedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ParentChildren", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ParentChildren_AspNetUsers_ParentId",
                        column: x => x.ParentId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ParentChildren_Children_ChildId",
                        column: x => x.ChildId,
                        principalTable: "Children",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "AppUsages",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DeviceId = table.Column<int>(type: "int", nullable: false),
                    PackageName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    AppName = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    UsageDate = table.Column<DateTime>(type: "date", nullable: false),
                    DurationSeconds = table.Column<long>(type: "bigint", nullable: false),
                    LastSyncedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AppUsages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AppUsages_Devices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "Devices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "DailyScreenTimes",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DeviceId = table.Column<int>(type: "int", nullable: false),
                    UsageDate = table.Column<DateTime>(type: "date", nullable: false),
                    TotalSeconds = table.Column<long>(type: "bigint", nullable: false),
                    LastSyncedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DailyScreenTimes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DailyScreenTimes_Devices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "Devices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "DeviceSyncLogs",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DeviceId = table.Column<int>(type: "int", nullable: false),
                    SyncType = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    StartedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RecordsCount = table.Column<int>(type: "int", nullable: false),
                    ErrorMessage = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeviceSyncLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DeviceSyncLogs_Devices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "Devices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Locations",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DeviceId = table.Column<int>(type: "int", nullable: false),
                    Latitude = table.Column<decimal>(type: "decimal(10,7)", nullable: false),
                    Longitude = table.Column<decimal>(type: "decimal(10,7)", nullable: false),
                    AccuracyMeters = table.Column<double>(type: "float", nullable: true),
                    RecordedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReceivedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Source = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Locations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Locations_Devices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "Devices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ScreenTimeLimits",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DeviceId = table.Column<int>(type: "int", nullable: false),
                    LimitType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    PackageName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    DailyLimitMinutes = table.Column<int>(type: "int", nullable: false),
                    IsEnabled = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ScreenTimeLimits", x => x.Id);
                    table.CheckConstraint("CK_ScreenTimeLimits_Minutes", "[DailyLimitMinutes] > 0");
                    table.CheckConstraint("CK_ScreenTimeLimits_Package", "([LimitType] = 'TOTAL' AND [PackageName] IS NULL) OR ([LimitType] = 'APP' AND [PackageName] IS NOT NULL AND LEN([PackageName]) > 0)");
                    table.CheckConstraint("CK_ScreenTimeLimits_Type", "[LimitType] IN ('TOTAL', 'APP')");
                    table.ForeignKey(
                        name: "FK_ScreenTimeLimits_Devices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "Devices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "TimeRequests",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ChildId = table.Column<int>(type: "int", nullable: false),
                    DeviceId = table.Column<int>(type: "int", nullable: false),
                    ScreenTimeLimitId = table.Column<int>(type: "int", nullable: false),
                    RequestedMinutes = table.Column<int>(type: "int", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    ReviewedBy = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReviewedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TimeRequests", x => x.Id);
                    table.CheckConstraint("CK_TimeRequests_Minutes", "[RequestedMinutes] > 0");
                    table.CheckConstraint("CK_TimeRequests_Status", "[Status] IN ('PENDING', 'APPROVED', 'REJECTED')");
                    table.ForeignKey(
                        name: "FK_TimeRequests_AspNetUsers_ReviewedBy",
                        column: x => x.ReviewedBy,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_TimeRequests_Children_ChildId",
                        column: x => x.ChildId,
                        principalTable: "Children",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_TimeRequests_Devices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "Devices",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_TimeRequests_ScreenTimeLimits_ScreenTimeLimitId",
                        column: x => x.ScreenTimeLimitId,
                        principalTable: "ScreenTimeLimits",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "TimeExtensions",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TimeRequestId = table.Column<int>(type: "int", nullable: false),
                    ScreenTimeLimitId = table.Column<int>(type: "int", nullable: false),
                    ExtraMinutes = table.Column<int>(type: "int", nullable: false),
                    EffectiveDate = table.Column<DateTime>(type: "date", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TimeExtensions", x => x.Id);
                    table.CheckConstraint("CK_TimeExtensions_Minutes", "[ExtraMinutes] > 0");
                    table.ForeignKey(
                        name: "FK_TimeExtensions_ScreenTimeLimits_ScreenTimeLimitId",
                        column: x => x.ScreenTimeLimitId,
                        principalTable: "ScreenTimeLimits",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_TimeExtensions_TimeRequests_TimeRequestId",
                        column: x => x.TimeRequestId,
                        principalTable: "TimeRequests",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_AppUsages_DeviceId_PackageName_UsageDate",
                table: "AppUsages",
                columns: new[] { "DeviceId", "PackageName", "UsageDate" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AspNetRoleClaims_RoleId",
                table: "AspNetRoleClaims",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "RoleNameIndex",
                table: "AspNetRoles",
                column: "NormalizedName",
                unique: true,
                filter: "[NormalizedName] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUserClaims_UserId",
                table: "AspNetUserClaims",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUserLogins_UserId",
                table: "AspNetUserLogins",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUserRoles_RoleId",
                table: "AspNetUserRoles",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "EmailIndex",
                table: "AspNetUsers",
                column: "NormalizedEmail");

            migrationBuilder.CreateIndex(
                name: "UserNameIndex",
                table: "AspNetUsers",
                column: "NormalizedUserName",
                unique: true,
                filter: "[NormalizedUserName] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Children_OtpRecipientParentId",
                table: "Children",
                column: "OtpRecipientParentId");

            migrationBuilder.CreateIndex(
                name: "IX_Children_UserId",
                table: "Children",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DailyScreenTimes_DeviceId_UsageDate",
                table: "DailyScreenTimes",
                columns: new[] { "DeviceId", "UsageDate" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Devices_ChildId",
                table: "Devices",
                column: "ChildId");

            migrationBuilder.CreateIndex(
                name: "IX_Devices_DeviceIdentifier",
                table: "Devices",
                column: "DeviceIdentifier",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DeviceSyncLogs_DeviceId_StartedAt",
                table: "DeviceSyncLogs",
                columns: new[] { "DeviceId", "StartedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Locations_DeviceId_RecordedAt",
                table: "Locations",
                columns: new[] { "DeviceId", "RecordedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_UserId_IsRead",
                table: "Notifications",
                columns: new[] { "UserId", "IsRead" });

            migrationBuilder.CreateIndex(
                name: "IX_OtpCodes_UserId_Purpose_ExpiresAt",
                table: "OtpCodes",
                columns: new[] { "UserId", "Purpose", "ExpiresAt" });

            migrationBuilder.CreateIndex(
                name: "IX_PairingCodes_ChildId",
                table: "PairingCodes",
                column: "ChildId");

            migrationBuilder.CreateIndex(
                name: "IX_PairingCodes_CreatedBy",
                table: "PairingCodes",
                column: "CreatedBy");

            migrationBuilder.CreateIndex(
                name: "IX_PairingCodes_SetupTokenHash",
                table: "PairingCodes",
                column: "SetupTokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ParentChildren_ChildId",
                table: "ParentChildren",
                column: "ChildId");

            migrationBuilder.CreateIndex(
                name: "IX_ParentChildren_ParentId_ChildId",
                table: "ParentChildren",
                columns: new[] { "ParentId", "ChildId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ScreenTimeLimits_DeviceId",
                table: "ScreenTimeLimits",
                column: "DeviceId",
                unique: true,
                filter: "[LimitType] = 'TOTAL'");

            migrationBuilder.CreateIndex(
                name: "IX_ScreenTimeLimits_DeviceId_PackageName",
                table: "ScreenTimeLimits",
                columns: new[] { "DeviceId", "PackageName" },
                unique: true,
                filter: "[LimitType] = 'APP'");

            migrationBuilder.CreateIndex(
                name: "IX_TimeExtensions_ScreenTimeLimitId",
                table: "TimeExtensions",
                column: "ScreenTimeLimitId");

            migrationBuilder.CreateIndex(
                name: "IX_TimeExtensions_TimeRequestId",
                table: "TimeExtensions",
                column: "TimeRequestId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TimeRequests_ChildId",
                table: "TimeRequests",
                column: "ChildId");

            migrationBuilder.CreateIndex(
                name: "IX_TimeRequests_DeviceId",
                table: "TimeRequests",
                column: "DeviceId");

            migrationBuilder.CreateIndex(
                name: "IX_TimeRequests_ReviewedBy",
                table: "TimeRequests",
                column: "ReviewedBy");

            migrationBuilder.CreateIndex(
                name: "IX_TimeRequests_ScreenTimeLimitId",
                table: "TimeRequests",
                column: "ScreenTimeLimitId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AppUsages");

            migrationBuilder.DropTable(
                name: "AspNetRoleClaims");

            migrationBuilder.DropTable(
                name: "AspNetUserClaims");

            migrationBuilder.DropTable(
                name: "AspNetUserLogins");

            migrationBuilder.DropTable(
                name: "AspNetUserRoles");

            migrationBuilder.DropTable(
                name: "AspNetUserTokens");

            migrationBuilder.DropTable(
                name: "DailyScreenTimes");

            migrationBuilder.DropTable(
                name: "DeviceSyncLogs");

            migrationBuilder.DropTable(
                name: "Locations");

            migrationBuilder.DropTable(
                name: "Notifications");

            migrationBuilder.DropTable(
                name: "OtpCodes");

            migrationBuilder.DropTable(
                name: "PairingCodes");

            migrationBuilder.DropTable(
                name: "ParentChildren");

            migrationBuilder.DropTable(
                name: "TimeExtensions");

            migrationBuilder.DropTable(
                name: "AspNetRoles");

            migrationBuilder.DropTable(
                name: "TimeRequests");

            migrationBuilder.DropTable(
                name: "ScreenTimeLimits");

            migrationBuilder.DropTable(
                name: "Devices");

            migrationBuilder.DropTable(
                name: "Children");

            migrationBuilder.DropTable(
                name: "AspNetUsers");
        }
    }
}
