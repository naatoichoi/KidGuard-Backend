
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class ChildAuthService {
  final FlutterSecureStorage _storage =
  const FlutterSecureStorage();

  Future<bool> hasPairedDevice() async {
    final identifier = await _storage.read(
      key: 'kidguard_device_identifier',
    );
    final secret = await _storage.read(
      key: 'kidguard_device_secret',
    );

    return identifier != null &&
        identifier.isNotEmpty &&
        secret != null &&
        secret.isNotEmpty;
  }

  Future<bool> refreshToken() async {
    final identifier = await _storage.read(
      key: 'kidguard_device_identifier',
    );
    final secret = await _storage.read(
      key: 'kidguard_device_secret',
    );

    if (identifier == null ||
        identifier.isEmpty ||
        secret == null ||
        secret.isEmpty) {
      return false;
    }

    final api = ApiService();

    try {
      final response = await api.post(
        'Pairing/refresh-token',
        authenticated: false,
        body: {
          'deviceIdentifier': identifier,
          'deviceSecret': secret,
        },
      );

      final data = Map<String, dynamic>.from(
        response as Map,
      );

      final token = data['token']?.toString();
      final deviceId = data['deviceId']?.toString();
      final childId = data['childId']?.toString();

      if (token == null ||
          token.isEmpty ||
          deviceId == null ||
          childId == null) {
        return false;
      }

      await _storage.write(
        key: 'kidguard_jwt',
        value: token,
      );
      await _storage.write(
        key: 'kidguard_device_id',
        value: deviceId,
      );
      await _storage.write(
        key: 'kidguard_child_id',
        value: childId,
      );
      await _storage.write(
        key: 'kidguard_device_name',
        value: data['deviceName']?.toString() ?? 'Thiết bị',
      );

      return true;
    } finally {
      api.dispose();
    }
  }
}
