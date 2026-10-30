import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  AuthService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;
  static const _storage = FlutterSecureStorage();

  Future<void> login({
    required String userName,
    required String password,
  }) async {
    await _api.post(
      'Auth/login',
      authenticated: false,
      body: {'userName': userName.trim(), 'password': password},
    );
  }

  Future<String> verifyOtp({
    required String userName,
    required String code,
  }) async {
    final data = await _api.post(
      'Auth/verify-otp',
      authenticated: false,
      body: {'userName': userName.trim(), 'code': code.trim()},
    );
    return persistSession(data);
  }

  Future<String> loginBiometric({
    required String userName,
    required String deviceId,
    required String secret,
  }) async {
    final data = await _api.post(
      'Auth/login-biometric',
      authenticated: false,
      body: {
        'userName': userName.trim(),
        'deviceId': deviceId,
        'secret': secret,
      },
    );
    return persistSession(data);
  }

  Future<void> enrollBiometric({
    required String deviceId,
    required String secret,
  }) async {
    await _api.post(
      'Auth/enroll-biometric',
      body: {'deviceId': deviceId, 'secret': secret},
    );
  }

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _api.get('Auth/profile');
    if (data is! Map) {
      throw const ApiException('Hồ sơ không hợp lệ.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateProfile({
    required String fullName,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
  }) async {
    await _api.put(
      'Auth/profile',
      body: {
        'fullName': fullName.trim(),
        'email': email?.trim(),
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<String> persistSession(dynamic data) async {
    if (data is! Map) throw const ApiException('Phản hồi đăng nhập không hợp lệ.');
    final token = data['accessToken'];
    final user = data['user'];
    final roles = user is Map ? user['roles'] : null;
    if (token is! String || token.isEmpty || roles is! List) {
      throw const ApiException('Thiếu accessToken hoặc roles trong phản hồi.');
    }
    final role = roles.any((r) => r.toString().toLowerCase() == 'parent')
        ? 'Parent'
        : roles.any((r) => r.toString().toLowerCase() == 'child')
        ? 'Child'
        : '';
    if (role.isEmpty) {
      throw const ApiException('Tài khoản chưa có quyền Parent/Child.');
    }
    await _storage.write(key: 'kidguard_jwt', value: token);
    await _storage.write(key: 'kidguard_role', value: role);
    if (role == 'Parent') await _storage.delete(key: 'kidguard_signed_out');
    await _storage.delete(key: 'kidguard_expires_at');
    final expires = data['expiresInSeconds'];
    if (expires is num && expires > 0) {
      await _storage.write(
        key: 'kidguard_expires_at',
        value: DateTime.now()
            .toUtc()
            .add(Duration(seconds: expires.toInt()))
            .toIso8601String(),
      );
    }
    return role;
  }

  Future<String?> getValidRole() async {
    final token = await _storage.read(key: 'kidguard_jwt');
    final role = await _storage.read(key: 'kidguard_role');
    final expiry = await _storage.read(key: 'kidguard_expires_at');
    if (token == null ||
        token.isEmpty ||
        (role != 'Parent' && role != 'Child')) {
      return null;
    }
    if (expiry == null) return null;
    final expiresAt = DateTime.tryParse(expiry);
    if (expiresAt == null || !DateTime.now().toUtc().isBefore(expiresAt)) {
      await logout();
      return null;
    }
    return role;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'kidguard_jwt');
    await _storage.delete(key: 'kidguard_role');
    await _storage.delete(key: 'kidguard_expires_at');
  }
}
