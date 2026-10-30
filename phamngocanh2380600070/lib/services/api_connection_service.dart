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
      if (ready.statusCode != 200) {
        throw const ApiException(
          'Backend chưa sẵn sàng. Hãy chạy lại project trong Visual Studio.',
        );
      }
      final api = await _client
          .get(Uri.parse('$normalized/Dashboard/parent'))
          .timeout(const Duration(seconds: 12));
      if (api.statusCode != 401) {
        throw const ApiException('Link chưa trỏ đến đúng API KidGuard.');
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
