# KidGuard — Backend và Flutter

- `phamngocanh/`: ASP.NET Core API, mở bằng Visual Studio qua `phamngocanh.slnx`.
- `flutter/`: ứng dụng Flutter Android, mở thư mục này bằng Android Studio.
- `flutter/README.md`: luồng sử dụng, quyền Android và hướng dẫn kiểm thử.

## Cấu hình backend

Không lưu mật khẩu SQL Server, SMTP hoặc khóa JWT trên GitHub. Trong Visual Studio, nhấn phải project → Manage User Secrets, rồi điền cấu hình theo `phamngocanh/secrets.example.json` bằng giá trị thật. Jwt:Key phải là chuỗi Base64 của ít nhất 32 byte ngẫu nhiên. Mỗi thành viên cấu hình User Secrets trên máy của mình.

Sau khi cấu hình SQL Server, áp dụng migration bằng `dotnet run --project phamngocanh -- --migrate`, rồi chạy backend bình thường trong Visual Studio. Khi dùng Conveyor, bật Access Over Internet.

## Chạy Flutter

```powershell
cd flutter
flutter pub get
flutter run
```

Trên cả hai điện thoại, vào Máy chủ → Link backend → dán Internet URL HTTPS của Conveyor → Kiểm tra và lưu. Khi đổi link, làm lại thao tác này và đăng nhập lại; không cần build lại APK.

## Kiểm thử

```powershell
dotnet test flutter/backend-review/BackendReview.Tests.csproj
cd flutter
flutter test
```

Dữ liệu database, bản sao lưu, cấu hình riêng và APK không được đưa vào repo. Script `flutter/maintenance/Reset-KidGuardData.ps1` mặc định chỉ kiểm tra; chỉ dùng `-Reset` khi thực sự muốn sao lưu và xóa dữ liệu.
