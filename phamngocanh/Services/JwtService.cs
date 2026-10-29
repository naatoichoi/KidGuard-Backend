
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using phamngocanh.Models;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace phamngocanh.Services
{
    public class JwtService
    {
        private readonly IConfiguration _configuration;
        private readonly UserManager<ApplicationUser> _userManager;

        public JwtService(
            IConfiguration configuration,
            UserManager<ApplicationUser> userManager)
        {
            _configuration = configuration;
            _userManager = userManager;
        }

        public async Task<string> GenerateTokenAsync(
            ApplicationUser user)
        {
            string key = _configuration["Jwt:Key"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình Jwt:Key.");

            string issuer = _configuration["Jwt:Issuer"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình Jwt:Issuer.");

            string audience = _configuration["Jwt:Audience"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình Jwt:Audience.");

            int expireMinutes = int.Parse(
                _configuration["Jwt:ExpireMinutes"] ?? "120");

            if (expireMinutes <= 0)
            {
                throw new InvalidOperationException(
                    "Jwt:ExpireMinutes phải lớn hơn 0.");
            }

            byte[] keyBytes = Convert.FromBase64String(key);

            var securityKey = new SymmetricSecurityKey(keyBytes);

            var credentials = new SigningCredentials(
                securityKey,
                SecurityAlgorithms.HmacSha256);

            var claims = new List<Claim>
            {
                new Claim(
                    JwtRegisteredClaimNames.Sub,
                    user.Id),

                new Claim(
                    JwtRegisteredClaimNames.UniqueName,
                    user.UserName ?? string.Empty),

                new Claim(
                    JwtRegisteredClaimNames.Jti,
                    Guid.NewGuid().ToString()),

                new Claim(
                    ClaimTypes.NameIdentifier,
                    user.Id),

                new Claim(
                    ClaimTypes.Name,
                    user.UserName ?? string.Empty)
            };

            var roles = await _userManager.GetRolesAsync(user);

            foreach (string role in roles)
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                notBefore: DateTime.UtcNow,
                expires: DateTime.UtcNow.AddMinutes(expireMinutes),
                signingCredentials: credentials);

            return new JwtSecurityTokenHandler()
                .WriteToken(token);
        }
    }
}
