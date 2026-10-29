
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace phamngocanh.Services
{
    public class EmailService : IEmailService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<EmailService> _logger;

        public EmailService(
            IConfiguration configuration,
            ILogger<EmailService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public async Task SendEmailAsync(
            string toEmail,
            string subject,
            string htmlBody)
        {
            string host = _configuration["Smtp:Host"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình Smtp:Host.");

            string fromEmail = _configuration["Smtp:Email"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình Smtp:Email.");

            string password = _configuration["Smtp:Password"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình Smtp:Password.");

            int port = int.Parse(
                _configuration["Smtp:Port"] ?? "587");

            var message = new MimeMessage();

            message.From.Add(
                new MailboxAddress("KidGuard", fromEmail));

            message.To.Add(
                MailboxAddress.Parse(toEmail));

            message.Subject = subject;

            message.Body = new BodyBuilder
            {
                HtmlBody = htmlBody
            }.ToMessageBody();

            using var client = new SmtpClient();

            try
            {
                // Kết nối Gmail qua STARTTLS
                await client.ConnectAsync(
                    host,
                    port,
                    SecureSocketOptions.StartTls);

                // Xác thực bằng Gmail App Password
                await client.AuthenticateAsync(
                    fromEmail,
                    password.Replace(" ", "").Trim());

                // Gửi email
                await client.SendAsync(message);

                await client.DisconnectAsync(true);

                _logger.LogInformation(
                    "Đã gửi email OTP thành công.");
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Lỗi khi gửi email qua SMTP.");

                throw;
            }
        }
    }
}
