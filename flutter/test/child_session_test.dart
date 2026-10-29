import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidguard/services/auth_service.dart';
import 'package:kidguard/services/child_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Đăng xuất không tự đăng nhập lại, vẫn giữ liên kết để áp dụng giới hạn',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'kidguard_device_identifier': 'test-phone',
        'kidguard_device_secret': 'enrollment-secret',
        'kidguard_jwt': 'ui-token',
        'kidguard_role': 'Child',
        'kidguard_expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      final child = ChildAuthService();
      expect(await child.hasPairedDevice(), isTrue);
      await child.logout();
      expect(await child.hasPairedDevice(), isFalse);
      expect(await AuthService().getValidRole(), isNull);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'kidguard_signed_out'), 'true');
      expect(await storage.read(key: 'kidguard_jwt'), isNull);
      expect(
        await storage.read(key: 'kidguard_device_identifier'),
        'test-phone',
      );
      expect(
        await storage.read(key: 'kidguard_device_secret'),
        'enrollment-secret',
      );
    },
  );
}
