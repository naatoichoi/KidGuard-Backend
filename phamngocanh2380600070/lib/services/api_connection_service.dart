import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_service.dart';

class ApiConnectionService {
  ApiConnectionService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  Future<String> check(String input) async {
    final normalized = ApiConfig.normalize(input);
    final base = Uri.parse(normalized);
    final health = base.replace(
      path: '${base.path.substring(0, base.path.length - 4)}/health',
    );
    try {
      final ready = await _client
          .get(health)
          .timeout(const Duration(seconds: 12));
      // Older Visual Studio backends do not expose /health. In that case,
      // verify the protected API before rejecting an otherwise valid tunnel.
      if (ready.statusCode != 200 && ready.statusCode != 404) {
        throw ApiException(
          'Kiểm tra /health trả HTTP ${ready.statusCode}. '
          'Kiểm tra backend, kết nối database và Access Over Internet trong Conveyor.',
          statusCode: ready.statusCode,
        );
      }
      final api = await _client
          .get(Uri.parse('$normalized/Dashboard/parent'))
          .timeout(const Duration(seconds: 12));
      if (api.statusCode != 401) {
        throw ApiException(
          'API /Dashboard/parent trả HTTP ${api.statusCode}, cần HTTP 401 khi chưa đăng nhập. '
          'Kiểm tra link Conveyor có trỏ đúng project KidGuard.',
          statusCode: api.statusCode,
        );
      }
      return normalized;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Không kết nối được. Kiểm tra link Conveyor và backend đang chạy.',
      );
    }
  }

  void dispose() => _client.close();
}
