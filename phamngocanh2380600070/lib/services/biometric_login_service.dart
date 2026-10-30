import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_service.dart';

class BiometricLoginService {
  BiometricLoginService({
    AuthService? auth,
    LocalAuthentication? localAuth,
    FlutterSecureStorage? storage,
  }) : _auth = auth ?? AuthService(),
       _localAuth = localAuth ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  static const userKey = 'kidguard_bio_user';
  static const deviceKey = 'kidguard_bio_device';
  static const secretKey = 'kidguard_bio_secret';
  static const completedKey = 'kidguard_first_otp_done';

  final AuthService _auth;
  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _storage;

  Future<bool> hasCompletedPasswordOtp() async =>
      await _storage.read(key: completedKey) == 'true';

  Future<void> markPasswordOtpCompleted() =>
      _storage.write(key: completedKey, value: 'true');

  Future<bool> isEnrolled() async {
    final user = await _storage.read(key: userKey);
    final device = await _storage.read(key: deviceKey);
    final secret = await _storage.read(key: secretKey);
    return user != null &&
        user.isNotEmpty &&
        device != null &&
        secret != null &&
        secret.length >= 32;
  }

  Future<String?> enrolledUserName() => _storage.read(key: userKey);

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Xác nhận khuôn mặt hoặc vân tay để đăng nhập KidGuard',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> enroll(String userName) async {
    if (!await authenticate(
      reason: 'Xác nhận khuôn mặt hoặc vân tay để bật đăng nhập lần sau',
    )) {
      return false;
    }
    final deviceId =
        await _storage.read(key: deviceKey) ??
        List.generate(16, (_) => Random.secure().nextInt(256))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
    final secret = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await _auth.enrollBiometric(deviceId: deviceId, secret: secret);
    await _storage.write(key: userKey, value: userName.trim());
    await _storage.write(key: deviceKey, value: deviceId);
    await _storage.write(key: secretKey, value: secret);
    return true;
  }

  Future<void> disable() async {
    await _storage.delete(key: userKey);
    await _storage.delete(key: secretKey);
  }

  Future<String> login() async {
    final user = await _storage.read(key: userKey);
    final device = await _storage.read(key: deviceKey);
    final secret = await _storage.read(key: secretKey);
    if (user == null || device == null || secret == null) {
      throw const FormatException(
        'Chưa bật đăng nhập khuôn mặt/vân tay trên máy này.',
      );
    }
    if (!await authenticate()) {
      throw const FormatException('Không nhận diện được khuôn mặt hoặc vân tay.');
    }
    return _auth.loginBiometric(
      userName: user,
      deviceId: device,
      secret: secret,
    );
  }
}
