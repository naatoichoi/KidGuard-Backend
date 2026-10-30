import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phamngocanh2380600070/config/api_config.dart';
import 'package:phamngocanh2380600070/services/api_connection_service.dart';
import 'package:phamngocanh2380600070/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await ApiConfig.load();
  });
  tearDown(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await ApiConfig.load();
  });
  test('Dán link gốc Conveyor hoặc /api đều được chuẩn hóa đúng', () {
    expect(
      ApiConfig.normalize(' https://new-link.conveyor.cloud/ '),
      'https://new-link.conveyor.cloud/api',
    );
    expect(
      ApiConfig.normalize('https://new-link.conveyor.cloud/api/'),
      'https://new-link.conveyor.cloud/api',
    );
  });
  test('Không chấp nhận localhost, HTTP hoặc URL chứa thông tin đăng nhập', () {
    for (final value in [
      'http://server.example',
      'https://localhost',
      'https://192.168.1.2',
      'https://user:password@server.example',
    ]) {
      expect(() => ApiConfig.normalize(value), throwsFormatException);
    }
  });
  test('Link đã lưu tiếp tục dùng sau khi nạp lại cấu hình', () async {
    await ApiConfig.save('https://new-link.conveyor.cloud/');
    await ApiConfig.load();
    expect(
      ApiConfig.endpoint('Auth/login').toString(),
      'https://new-link.conveyor.cloud/api/Auth/login',
    );
    expect(
      await const FlutterSecureStorage().read(key: 'kidguard_api_base_url'),
      'https://new-link.conveyor.cloud/api',
    );
  });
  test('Kiểm tra đúng health và API mà không gửi JWT cũ', () async {
    final service = ApiConnectionService(
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.headers.containsKey('authorization'), isFalse);
        if (request.url.path == '/health') return http.Response('', 200);
        expect(request.url.path, '/api/Dashboard/parent');
        return http.Response('', 401);
      }),
    );
    addTearDown(service.dispose);
    expect(
      await service.check('https://new-link.conveyor.cloud'),
      'https://new-link.conveyor.cloud/api',
    );
  });
  test('Backend chưa sẵn sàng không ghi đè URL hiện tại', () async {
    final current = ApiConfig.baseUrl;
    final service = ApiConnectionService(
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.check('https://bad-link.conveyor.cloud'),
      throwsA(isA<ApiException>()),
    );
    expect(ApiConfig.baseUrl, current);
  });
  test('Trang web thông thường không được coi là API KidGuard', () async {
    final service = ApiConnectionService(
      client: MockClient((_) async => http.Response('<html></html>', 200)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.check('https://other.example'),
      throwsA(isA<ApiException>()),
    );
  });
}
