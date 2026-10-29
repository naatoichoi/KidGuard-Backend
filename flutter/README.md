# KidGuard — Flutter quản lý điện thoại trẻ em

Backend ASP.NET Core ở ../phamngocanh. Mã backend đã được sửa trực tiếp; thư mục backend-review chứa bản đối chiếu và bộ kiểm thử liên kết với mã backend thật.

## Luồng tài khoản đã thống nhất

1. Phụ huynh đăng ký email → đăng nhập username/password → nhận OTP email → xác minh vào vai trò Parent.
2. Trên máy trẻ, chọn tạo QR. Phụ huynh quét QR trên máy trẻ.
3. Sau khi quét, phụ huynh nhập tên con, username riêng, mật khẩu và xác nhận mật khẩu. Backend tạo tài khoản Child có password hash, liên kết phụ huynh và thiết bị trong transaction; QR chỉ dùng một lần, hết hạn sau 5 phút.
4. Máy trẻ nhận phiên và tự vào màn hình Child. Lần sau mở app còn phiên thiết bị thì tự vào; nếu đăng xuất, dùng username/password và OTP gửi về email phụ huynh, không quét QR lại trên điện thoại đã ghép.
5. Đăng xuất chỉ xóa phiên giao diện, giữ đăng ký thiết bị và hồ sơ. Dịch vụ giám sát đã được đồng ý bật vẫn tiếp tục thực hiện giới hạn; mở app lại không tự đăng nhập vào Child sau khi đăng xuất.
6. Trên máy Parent, biểu tượng tài khoản cạnh tên con cho phép đặt lại username/password cho đúng hồ sơ. Dùng được với tài khoản QR cũ có tên ngẫu nhiên/chưa có mật khẩu; giữ nguyên thiết bị và lịch sử. Không tạo hồ sơ mới để sửa tài khoản cũ.

Nếu cài lại app/xóa dữ liệu làm mất mã định danh thiết bị, không thể coi đó là cùng đăng ký cũ để bỏ qua ghép nối. Lần đăng nhập lại không cần QR trong phạm vi thiết bị đã ghép và còn thông tin định danh.

## Theo dõi, khóa tổng và chặn từng app

Trên Child → “Bật theo dõi và khóa khi hết giờ”, phụ huynh cấp:

- Quyền truy cập thời gian sử dụng Android.
- Trợ năng “KidGuard · Giới hạn của phụ huynh”: nhận tên package app đang mở, không đọc nội dung màn hình/tin nhắn.
- Quyền quản trị thiết bị, chỉ yêu cầu force-lock, để khóa màn hình.
- Quyền thông báo để có lối mở KidGuard/xin thêm giờ từ thanh thông báo.

Sau khi cấp đủ quyền, nhấn “Đồng ý bật giám sát và khóa khi hết giờ”. Có thể cần cho phép Restricted settings trong thông tin ứng dụng trên một số bản Android khi cài APK ngoài store. Nên có PIN/mật khẩu khóa màn hình của Android.

- Giới hạn TOTAL: đạt số giây cho phép thì gọi DevicePolicyManager.lockNow() khi đang dùng màn hình không thuộc nhóm ngoại lệ. Đây là khóa màn hình thật của Android.
- Giới hạn APP: màn hình chặn của dịch vụ trợ năng che riêng app đã hết giờ; về Home hoặc dùng app khác vẫn được. Không giả vờ đình chỉ/gỡ app bằng API không được cấp quyền.
- KidGuard, Cài đặt và các màn hình cuộc gọi/khẩn cấp được miễn chặn để có đường xin thêm giờ và khôi phục thiết bị. Không phải chế độ kiosk/Device Owner chống mọi cách vượt khóa.
- Dịch vụ Android được hệ thống liên kết khi bật trợ năng, kiểm tra khoảng 3 giây, hoạt động ngoài màn hình Flutter. Đọc UsageEvents theo một dòng thời gian foreground, cắt đúng ngày UTC và thời điểm tắt màn hình; không cộng chồng các bucket UsageStats. KidGuard, launcher và SystemUI không được tính vào thời gian giới hạn.
- Đồng bộ thời gian và tải giới hạn khoảng 30 giây khi có mạng. Thời gian được duyệt thêm tính cho đúng ngày, hết hiệu lực khi sang ngày UTC mới. Mất mạng tiếp tục dùng quy tắc đã tải; thay đổi từ Parent cần mạng để tới máy trẻ.
- Nếu quyền trợ năng/quyền Usage Access bị tắt, hệ điều hành dừng dịch vụ, ứng dụng bị force-stop hoặc bị gỡ, không cam kết tiếp tục khóa. Không có cơ chế bí mật tự cấp lại quyền.

Parent đặt giới hạn tổng hoặc tìm/chọn app theo tên từ danh sách máy trẻ đã đồng bộ, không nhập package name. Danh sách gồm cả app chưa dùng hôm nay (0 phút), lấy nhãn thật từ Android. Package chỉ là mã nội bộ để khóa đúng app; backend từ chối package chưa có trong dữ liệu đồng bộ. Trong báo cáo thời gian từng app có nút Giới hạn để mở đúng app. Màn hình giới hạn có tạo/đọc/sửa/xóa; chỉ Parent sở hữu thiết bị được sửa. Giới hạn có lịch sử xin thêm giờ trả 409 khi xóa, hướng dẫn sửa để tắt nhằm giữ lịch sử và tránh lỗi khóa ngoại. Trẻ không tự sửa giới hạn.

## Cảm biến và tính năng tự đề xuất

Child → biểu tượng vận động: nghỉ mắt và vận động 30 giây. Hiển thị gia tốc tuyến tính thật, đếm giây có chuyển động và phản hồi cuối phiên. Máy thiếu cảm biến báo lỗi; rời app dừng phiên. Không tự cộng thời gian sử dụng, kết quả hiện chỉ trong phiên. Đây là đề xuất sáng tạo cho bài, chưa chứng minh độc nhất trên thị trường.

Giao diện và nghiệp vụ mobile dùng Flutter. Kotlin chỉ làm cầu nối tới API hệ điều hành Android cho cảm biến, UsageEvents, trợ năng và khóa màn hình; không sử dụng SDK lập trình mobile khác. Hiện hỗ trợ cấu hình Android, không cam kết iOS có khả năng khóa tương tự.

## Chạy cho cả nhóm

Cần Flutter tương thích environment.sdk trong pubspec.yaml, Android SDK/JDK, backend có SQL Server và SMTP thật. Stop rồi Run lại project trong Visual Studio sau thay đổi backend.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://YOUR_PUBLIC_API/api
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://YOUR_PUBLIC_API/api
```

Không dùng URL ví dụ nguyên văn. URL mặc định đã cập nhật theo Conveyor của nhóm: https://tallaquaboat3.conveyor.cloud/api. Theo cách thầy hướng dẫn bài thực hành 6, nhóm tiếp tục dùng Conveyor; giữ máy tính, backend Visual Studio và Access Over Internet hoạt động. Nếu Conveyor đổi URL, trên cả hai máy mở Máy chủ → dán Internet URL mới vào Link backend → Kiểm tra và lưu → đăng nhập lại. Không cần build lại APK; URL được lưu riêng trên mỗi máy. Client yêu cầu HTTPS và chặn localhost/dải IPv4 riêng phổ biến.

Bản đồ đã chuyển sang Flutter Map + OpenStreetMap, không cần khóa Google Maps. Cần Internet để tải các ô bản đồ. Có dự phòng OpenTopoMap (© OpenStreetMap contributors, SRTM; CC-BY-SA), ghi nguồn và cache theo HTTP headers; không tải sẵn hàng loạt. Địa chỉ được tra bằng Android Geocoder, lưu cùng tọa độ trên backend. Nếu không tra được địa chỉ, vẫn giữ điểm ghim/GPS và báo rõ thiếu địa chỉ.

## Gửi vị trí và thử với Pixel 7

- Mặc định con bấm Gửi vị trí của con: lấy GPS một lần, gửi tọa độ/địa chỉ và tạo thông báo LOCATION_SHARED trong tài khoản phụ huynh. Chạm thông báo để mở bản đồ. Đây là thông báo trong ứng dụng, chưa phải push FCM khi app Parent đóng.
- Parent đọc vị trí đã gửi, gồm bản đồ, địa chỉ, thời điểm, sai số và lịch sử. Làm mới ở Parent không yêu cầu máy trẻ bật GPS từ xa.
- Tùy chọn Tự gửi khi mở ứng dụng mặc định tắt; nếu bật, chỉ thử khi đã có quyền và GPS bật, tối đa mỗi 15 phút, không phát thông báo liên tục. Không có theo dõi GPS nền liên tục.
- GPS mới chờ tối đa 15 giây. Máy ảo dùng Android LocationManager để nhận geo fix; điện thoại thật dùng provider thông thường. Khi timeout, chỉ dùng điểm lưu gần nhất trong 10 phút và hiển thị rõ điểm cũ. Có nút mở GPS/cài đặt quyền.
- Ứng dụng luôn lấy vị trí do hệ điều hành cung cấp, không có nút gửi dữ liệu giả hoặc địa chỉ hardcode. Trên máy ảo, tự chọn vị trí trong Extended Controls → Location của Android Emulator.
- Database đã áp dụng migration 20261029224142_AddLocationAddress: chỉ thêm Address nullable, không xóa dữ liệu cũ. Sau sửa backend cần Stop/Run lại Visual Studio. Cài APK mới trên cả máy ảo Child và điện thoại Parent.
- Để Parent thấy danh sách app: trên Child cấp quyền thống kê, mở Thời gian sử dụng và bấm Đồng bộ danh sách & thời gian; hoặc bật giám sát để tự đồng bộ khoảng 30 giây. Parent mở Giới hạn thời gian, chọn app theo tên và đặt phút. Hết giờ app chỉ chặn app đó; tổng điện thoại vẫn là giới hạn riêng.

## Triển khai thay Conveyor

Đã chuẩn bị deploy/Dockerfile, Compose SQL Server + API + Caddy HTTPS, mẫu .env và script xuất gói không chứa cấu hình bí mật. Xem deploy/README.md. Cần VPS/domain và thông tin SMTP thật để triển khai; chưa có dịch vụ Internet mới được tạo.

Program.cs backend có /health (200 khi kết nối DB và đã áp dụng migration), chỉ tin proxy được cấu hình Proxy:KnownAddress và lệnh --migrate dành cho bước triển khai rõ ràng. Startup bình thường không tự sửa schema. Không chạy migrate trên dữ liệu đang có khi chưa sao lưu.

## Trạng thái kiểm tra và các mục còn lại

- Backend build thành công, 0 warning/error. Có bộ kiểm thử tài khoản QR, mật khẩu thật, QR hết hạn/dùng lại, quyền khôi phục thiết bị, quyền Parent sửa tài khoản cũ và CRUD giới hạn.
- Android có kiểm thử ngưỡng khóa tổng, khóa app, thời gian được duyệt thêm/ngày mới và tính timeline không trùng khi chuyển app/tắt màn hình.
- Flutter có kiểm thử API query, DELETE 204, lỗi 403, URL HTTPS, đăng xuất giữ enrollment, thiếu cảm biến và dừng cảm biến khi ra nền.
- 21 kiểm thử backend, 18 kiểm thử Flutter và 5 kiểm thử Android đã đạt. Migration địa chỉ đã áp dụng thành công lên SQL Server hiện tại. Các kiểm thử backend dùng Identity thật với EF InMemory; chưa thay thế nghiệm thu SMTP/HTTP giữa hai máy, khóa trên điện thoại thật hoặc VPS/domain thật.
- Tên project Flutter vẫn là kidguard: cần xác nhận tên cá nhân chính xác trước khi đổi, vì đề chấm sai tên là 0 điểm. Không tự suy đoán tên chỉ từ tên thư mục backend.
- Bản APK debug ở build/app/outputs/flutter-apk/app-debug.apk. Release hiện vẫn dùng debug signing, phục vụ chạy thử nội bộ.

Kiểm thử backend: dotnet test backend-review/BackendReview.Tests.csproj. Nếu backend ở đường dẫn khác, truyền -p:BackendRoot=<đường dẫn>. Kiểm thử Android: chạy ./gradlew.bat :app:testDebugUnitTest trong android.

Nguồn API nền tảng: https://developer.android.com/reference/android/app/admin/DevicePolicyManager và https://developer.android.com/reference/android/accessibilityservice/AccessibilityService.
