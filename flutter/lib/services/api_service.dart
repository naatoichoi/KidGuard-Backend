import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _storage = FlutterSecureStorage();

  Future<dynamic> get(String path, {Map<String, String>? query, bool authenticated = true}) =>
      _request('GET', path, query: query, authenticated: authenticated);

  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) =>
      _request('POST', path, body: body, authenticated: authenticated);

  Future<dynamic> put(String path, {Object? body, bool authenticated = true}) =>
      _request('PUT', path, body: body, authenticated: authenticated);

  Future<dynamic> _request(String method, String path,
      {Map<String, String>? query, Object? body, bool authenticated = true}) async {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${ApiConfig.baseUrl}/$cleanPath').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await _storage.read(key: 'kidguard_jwt');
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    }
    try {
      late http.Response response;
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers).timeout(ApiConfig.timeout);
      } else if (method == 'POST') {
        response = await _client.post(uri, headers: headers, body: jsonEncode(body)).timeout(ApiConfig.timeout);
      } else if (method == 'PUT') {
        response = await _client.put(uri, headers: headers, body: jsonEncode(body)).timeout(ApiConfig.timeout);
      } else {
        throw const ApiException('HTTP method không hỗ trợ.');
      }
      dynamic data;
      if (response.body.trim().isNotEmpty) {
        try { data = jsonDecode(response.body); } on FormatException { data = response.body; }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Lỗi HTTP ${response.statusCode}';
        if (data is Map) message = (data['message'] ?? data['title'] ?? message).toString();
        throw ApiException(message, statusCode: response.statusCode);
      }
      return data;
    } on ApiException { rethrow; }
    catch (e) { throw ApiException('Không thể kết nối Backend: $e'); }
  }

  void dispose() => _client.close();
}
