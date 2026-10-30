import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:phamngocanh2380600070/services/appearance_settings.dart';
import 'package:phamngocanh2380600070/services/auth_service.dart';
import 'package:phamngocanh2380600070/services/biometric_login_service.dart';
import 'package:phamngocanh2380600070/screens/common/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cỡ chữ và màu nền được lưu trên máy', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final settings = AppearanceSettings();
    await settings.setFontScale(1.2);
    await settings.setBackground(const Color(0xFFFFF8E7));
    final loaded = AppearanceSettings();
    await loaded.load();
    expect(loaded.fontScale, 1.2);
    expect(loaded.background.toARGB32(), const Color(0xFFFFF8E7).toARGB32());
  });

  testWidgets('Child có thể đổi giao diện mà không cần API hồ sơ Parent', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'kidguard_jwt': 'child-token',
      'kidguard_role': 'Child',
      'kidguard_expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });
    final appearance = AppearanceSettings();
    await appearance.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appearance,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cỡ chữ'), findsOneWidget);
    expect(find.text('Màu nền'), findsOneWidget);
    expect(find.text('Hồ sơ'), findsNothing);
  });

  test('Đăng xuất vẫn giữ khóa sinh trắc học cho lần sau', () async {
    FlutterSecureStorage.setMockInitialValues({
      'kidguard_jwt': 'token',
      'kidguard_role': 'Parent',
      'kidguard_expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      BiometricLoginService.userKey: 'guardian',
      BiometricLoginService.deviceKey: 'phone-1',
      BiometricLoginService.secretKey: 'secret-value-that-is-long-enough',
      BiometricLoginService.completedKey: 'true',
    });
    await AuthService().logout();
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'kidguard_jwt'), isNull);
    expect(await storage.read(key: BiometricLoginService.userKey), 'guardian');
    expect(
      await storage.read(key: BiometricLoginService.secretKey),
      'secret-value-that-is-long-enough',
    );
    expect(await BiometricLoginService().isEnrolled(), isTrue);
    expect(await BiometricLoginService().hasCompletedPasswordOtp(), isTrue);
  });
}
