using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace phamngocanh.Migrations
{
    /// <inheritdoc />
    public partial class AddPairingDeviceSecret : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DeviceSecretHash",
                table: "PairingCodes",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DeviceSecretHash",
                table: "PairingCodes");
        }
    }
}
