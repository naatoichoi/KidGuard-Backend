# KidGuard — phamngocanh — Backend và Flutter

Bản cập nhật gồm ứng dụng Flutter và ASP.NET Core API, giữ tên project cá nhân theo yêu cầu môn học.

- `phamngocanh/`: backend .NET 10, SQL Server, migration và dịch vụ email OTP. Mở `phamngocanh.slnx` bằng Visual Studio.
- `phamngocanh2380600070/`: ứng dụng Flutter/Dart cho Android.
- `backend-review/`: 24 kiểm thử backend.
- `deploy/`: cấu hình Docker Compose và hướng dẫn VPS.
- `maintenance/`: công cụ kiểm tra/reset dữ liệu, mặc định chỉ đọc.
- `CHUC_NANG_DA_THUC_HIEN.txt`: đối chiếu chức năng với đề kiểm tra.

## Cấu hình backend

Cần .NET SDK 10, SQL Server và tài khoản SMTP hỗ trợ STARTTLS. Sao chép `phamngocanh/appsettings.Local.example.json` thành `phamngocanh/appsettings.Development.json`, rồi điền cấu hình riêng. Khóa JWT phải là chuỗi Base64 của ít nhất 32 byte ngẫu nhiên. Có thể cấu hình bằng Manage User Secrets trong Visual Studio. File cấu hình riêng bị Git bỏ qua; không đưa mật khẩu thật lên GitHub.

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet restore phamngocanh/phamngocanh.csproj
# DB mới: áp dụng migration. DB đang có dữ liệu: sao lưu trước.
dotnet run --project phamngocanh/phamngocanh.csproj -- --migrate
dotnet run --project phamngocanh/phamngocanh.csproj --urls http://localhost:5269
```

Backend nghe cổng nội bộ; dùng Conveyor bật Access Over Internet hoặc VPS để app truy cập HTTPS công khai. App không gọi localhost. `/health` trả 200 khi database kết nối được và đã áp dụng đủ migration.

## Swagger để kiểm tra API

Mở `https://greatorangetower88.conveyor.cloud/swagger/index.html` để xem và thử toàn bộ API. Trang gốc `/` và `/api` cũng chuyển tới Swagger. Nếu Conveyor đổi tên miền, giữ đường dẫn `/swagger/index.html` trên tên miền mới.

Thử `Auth/register-parent` → `Auth/login` → lấy OTP qua email → `Auth/verify-otp`. Sao chép `accessToken`, bấm **Authorize**, dán token không thêm chữ Bearer. API Parent/Child vẫn kiểm tra vai trò và quyền sở hữu; không có cơ chế bỏ qua đăng nhập. Đo chuyển động và đổi giao diện là chức năng Flutter cục bộ nên không có API riêng.

API bổ sung trong nhóm **ScreenTime**: `GET /api/ScreenTime/app-lock/{deviceId}?packageName=com.google.android.youtube`. Endpoint yêu cầu JWT Parent/Child đúng thiết bị, trả `shouldBlock: true`, `action: BLOCK_APP` nếu ứng dụng đã hết giới hạn APP theo dữ liệu đồng bộ ngày UTC hiện tại. Nếu còn thời gian hoặc không có giới hạn APP đang bật thì trả `shouldBlock: false`, `action: ALLOW_APP`. Việc được duyệt thêm giờ được tính vào thời gian cho phép. `NO_LIMIT` có thời gian còn lại là null, không phải 0. Đây là quyết định backend để Android thực thi; không xác nhận điện thoại đã khóa. API giới hạn tổng và toàn bộ endpoint cũ vẫn giữ nguyên.

## Chạy Flutter

```powershell
cd phamngocanh2380600070
flutter pub get
flutter run
```

API mặc định hiện tại: `https://greatorangetower88.conveyor.cloud/api`. Khi Conveyor đổi link, vào Máy chủ → dán Internet URL HTTPS → Kiểm tra và lưu trên từng thiết bị.

Lần đầu đăng nhập bằng mật khẩu + OTP email. Sau OTP có thể bật sinh trắc học cho lần sau. Máy trẻ tạo QR, máy phụ huynh quét để ghép và tạo tài khoản trẻ. Quyền Usage Access, trợ năng và quản trị thiết bị cần được cấp theo hướng dẫn nếu dùng tính năng giới hạn.

## Kiểm thử

Chạy từ thư mục gốc repository:

```powershell
dotnet test backend-review/BackendReview.Tests.csproj
cd phamngocanh2380600070
flutter test
```

Bản tách đã đạt 24 kiểm thử backend và 26 kiểm thử Flutter; backend build không có warning/error. Đã build, cài và mở app trên OPPO CPH2237 và máy ảo Pixel 7. Các kết quả này không thay thế kiểm tra đầy đủ OTP, GPS và quyền khóa trên thiết bị thật.

Nếu dùng script maintenance, truyền `-BackendRoot ./phamngocanh`. Không dùng `-Reset` khi muốn giữ tài khoản. Cấu hình VPS được chuẩn bị trong `deploy/README.md`; source API ở thư mục `phamngocanh/` và compose đã trỏ tới thư mục này. Chưa xác nhận VPS chạy thường trực.
