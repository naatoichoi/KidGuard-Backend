import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phamngocanh2380600070/config/api_config.dart';
import 'package:phamngocanh2380600070/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gửi JWT trong Authorization Bearer cho API cần đăng nhập', () async {
    FlutterSecureStorage.setMockInitialValues({'kidguard_jwt': 'test-token'});
    final api = ApiService(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.dispose);
    await api.get('Auth/profile');
  });

  test('Giữ bộ lọc lịch sử khi đường dẫn đã có query', () async {
    final api = ApiService(
      client: MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.queryParameters, {
          'page': '1',
          'pageSize': '50',
          'date': '2026-10-29',
        });
        return http.Response('{"locations":[]}', 200);
      }),
    );
    addTearDown(api.dispose);
    await api.get(
      'Locations/child/1/history?page=1&pageSize=50',
      query: {'date': '2026-10-29'},
      authenticated: false,
    );
  });

  test('DELETE chấp nhận phản hồi 204 không có JSON', () async {
    final api = ApiService(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/ScreenTimeLimits/7'));
        return http.Response('', 204);
      }),
    );
    addTearDown(api.dispose);
    expect(
      await api.delete('ScreenTimeLimits/7', authenticated: false),
      isNull,
    );
  });

  test('Lỗi phân quyền từ backend không bị chuyển thành thành công', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response('{"message":"Forbidden"}', 403),
      ),
    );
    addTearDown(api.dispose);
    await expectLater(
      api.delete('ScreenTimeLimits/7', authenticated: false),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('API mặc định sử dụng HTTPS công khai', () {
    final endpoint = ApiConfig.endpoint('Auth/login');
    expect(endpoint.scheme, 'https');
    expect(endpoint.host, isNot('localhost'));
  });
}
