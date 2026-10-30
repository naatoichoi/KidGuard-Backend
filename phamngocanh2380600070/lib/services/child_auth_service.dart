import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'guard_service.dart';

class ChildAuthService {
  static const _storage = FlutterSecureStorage();
  String _secret() => List.generate(32, (_) => Random.secure().nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();

  Future<bool> hasPairedDevice() async {
    if (await _storage.read(key: 'kidguard_signed_out') == 'true') return false;
    final identifier = await _storage.read(key: 'kidguard_device_identifier');
    final secret = await _storage.read(key: 'kidguard_device_secret');
    return identifier != null &&
        identifier.isNotEmpty &&
        secret != null &&
        secret.isNotEmpty;
  }

  /// After OTP, authenticate the already enrolled phone without scanning again.
  Future<bool> restoreAfterOtp() async {
    final identifier = await _storage.read(key: 'kidguard_device_identifier');
    if (identifier == null || identifier.isEmpty) {
      throw const ApiException(
        'Điện thoại chưa được ghép. Nhờ phụ huynh quét QR lần đầu.',
      );
    }
    final api = ApiService();
    final secret = _secret();
    try {
      final data = await api.post(
        'Pairing/login-device',
        body: {'deviceIdentifier': identifier, 'deviceSecret': secret},
      );
      await _save(Map<String, dynamic>.from(data as Map), identifier, secret);
      await _storage.delete(key: 'kidguard_signed_out');
      return true;
    } finally {
      api.dispose();
    }
  }

  Future<void> _save(
    Map<String, dynamic> data,
    String identifier,
    String secret,
  ) async {
    final token = data['token']?.toString() ?? '';
    final deviceId = int.tryParse('${data['deviceId']}') ?? 0;
    final childId = int.tryParse('${data['childId']}') ?? 0;
    if (token.isEmpty || deviceId <= 0 || childId <= 0) {
      throw const ApiException('Phản hồi xác thực thiết bị không hợp lệ.');
    }
    await _storage.write(key: 'kidguard_jwt', value: token);
    await _storage.write(key: 'kidguard_device_id', value: '$deviceId');
    await _storage.write(key: 'kidguard_child_id', value: '$childId');
    await _storage.write(
      key: 'kidguard_device_name',
      value: data['deviceName']?.toString() ?? 'Thiết bị',
    );
    await _storage.write(key: 'kidguard_device_secret', value: secret);
    await _storage.write(key: 'kidguard_role', value: 'Child');
    await GuardService.configure(
      token: token,
      deviceId: deviceId,
      identifier: identifier,
      secret: secret,
    );
  }

  Future<bool> refreshToken() async {
    if (!await hasPairedDevice()) return false;
    final identifier = (await _storage.read(
      key: 'kidguard_device_identifier',
    ))!;
    final secret = (await _storage.read(key: 'kidguard_device_secret'))!;
    final api = ApiService();
    try {
      final data = await api.post(
        'Pairing/refresh-token',
        authenticated: false,
        body: {'deviceIdentifier': identifier, 'deviceSecret': secret},
      );
      if (await _storage.read(key: 'kidguard_signed_out') == 'true') {
        return false;
      }
      await _save(Map<String, dynamic>.from(data as Map), identifier, secret);
      return true;
    } finally {
      api.dispose();
    }
  }

  Future<void> logout() async {
    // Sign out of the UI. Enrollment stays so signing out does not bypass limits.
    await _storage.write(key: 'kidguard_signed_out', value: 'true');
    await AuthService().logout();
  }
}
