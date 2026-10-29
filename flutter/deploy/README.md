# Bộ triển khai backend lên VPS

Đây là cấu hình đã chuẩn bị, **chưa triển khai lên Internet**. Cần VPS Linux x86-64 có Docker Compose, domain trỏ về IP VPS và cổng 80/443 mở. SQL Server Developer chỉ dành cho phát triển/học tập. Không tự mua VPS hoặc tạo dịch vụ trả phí.

Conveyor cần project Visual Studio đang chạy; phù hợp thử máy nhưng không độc lập với máy cá nhân: https://conveyor.cloud/Home/How_To_Install.

## Chuẩn bị gói từ Windows

Chạy từ project Flutter:

```powershell
./deploy/Export-Backend.ps1
```

Script tạo ZIP trong build/vps-<thời điểm>.zip, gồm backend và deploy. Không sao chép appsettings hiện tại, User Secrets, bin/obj, file .http hoặc cấu hình Visual Studio. Chỉ có mẫu .env, không có mật khẩu thật. Đây là database mới; không tự chuyển dữ liệu SQL Server trên máy cá nhân.

## Chạy trên VPS

Giải nén thành hai thư mục backend và deploy cùng cấp. Vào deploy; sao chép .env.example thành .env rồi điền domain thật, mật khẩu database mới, khóa JWT ngẫu nhiên Base64 tối thiểu 32 byte và tài khoản SMTP thật (STARTTLS). Không dùng giá trị mẫu để chạy thật. Bảo vệ .env bằng quyền chỉ chủ sở hữu đọc.

```sh
cp .env.example .env
chmod 600 .env
# Chỉnh .env trước khi chạy các lệnh dưới.
docker compose config --quiet
docker compose build api
docker compose up -d db
# Chỉ chạy trên DB mới hoặc sau khi sao lưu DB đang có:
docker compose run --rm api --migrate
docker compose up -d api caddy
curl --fail https://YOUR_API_DOMAIN/health
```

Lệnh migrate áp dụng các EF migration hiện có; startup bình thường không tự sửa schema. Database và chứng chỉ nằm trong Docker volumes. Không xóa volumes khi cập nhật. Trước lần cập nhật database tiếp theo phải sao lưu. Cấu hình dùng sa để đơn giản bài học; khi vận hành thực tế cần tài khoản database riêng có quyền phù hợp.

API và SQL Server không công bố cổng trực tiếp ra Internet. Caddy cấp HTTPS và chuyển tiếp tới API. Program.cs chỉ tin địa chỉ proxy 172.29.0.10. Nếu subnet này xung đột mạng VPS, đổi subnet và IP Caddy, đồng thời đổi Proxy__KnownAddress cho khớp.

## Chuyển Flutter sang URL mới

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR_API_DOMAIN/api
flutter build apk --debug --dart-define=API_BASE_URL=https://YOUR_API_DOMAIN/api
```

Sau khi build, thử đăng ký → OTP email → ghép QR tạo tài khoản Child → đăng xuất/đăng nhập lại → gửi thời gian/vị trí → đặt giới hạn. Tắt Visual Studio và máy cá nhân rồi thử lại từ mạng di động để xác nhận API hoạt động độc lập.

Chưa kiểm thử triển khai VPS hoặc phát hành chứng chỉ thật vì chưa có máy chủ/domain. Tài liệu nền: [Microsoft .NET Docker](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/docker/building-net-docker-images?view=aspnetcore-10.0), [proxy tin cậy](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer?view=aspnetcore-10.0), [Docker Compose build](https://docs.docker.com/reference/compose-file/build/), [Caddy HTTPS](https://caddyserver.com/docs/automatic-https).
