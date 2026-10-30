import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  ApiConfig._();
  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tallaquaboat3.conveyor.cloud/api',
  );
  static const _storage = FlutterSecureStorage();
  static String _baseUrl = defaultBaseUrl;
  static String get baseUrl => _baseUrl;
  static const Duration timeout = Duration(seconds: 25);

  static String normalize(String value) {
    final base = Uri.parse(value.trim());
    final host = base.host.toLowerCase();
    if (base.scheme != 'https' ||
        host.isEmpty ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host == '::1' ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host) ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const FormatException('Nhập link HTTPS công khai của backend.');
    }
    final path = base.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isNotEmpty && !path.endsWith('/api')) {
      throw const FormatException(
        'Dán link gốc từ Conveyor hoặc link kết thúc bằng /api.',
      );
    }
    return base.replace(path: path.isEmpty ? '/api' : path).toString();
  }

  static Future<void> load() async {
    try {
      final value = await _storage.read(key: 'kidguard_api_base_url');
      _baseUrl = normalize(value ?? defaultBaseUrl);
    } catch (_) {
      _baseUrl = defaultBaseUrl;
    }
  }

  static Future<void> save(String value) async {
    final normalized = normalize(value);
    await _storage.write(key: 'kidguard_api_base_url', value: normalized);
    _baseUrl = normalized;
  }

  static Uri endpoint(String path, {Map<String, String>? query}) {
    final base = normalize(baseUrl);
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$base/$cleanPath');
    return query == null
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }
}
