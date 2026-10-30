import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phamngocanh2380600070/services/api_service.dart';
import 'package:phamngocanh2380600070/services/location_sharing_service.dart';

Position point(DateTime time) => Position(
  latitude: 21.02867,
  longitude: 105.85215,
  timestamp: time,
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
  isMocked: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'kidguard_jwt': 'test-token',
    }),
  );

  test('Tắt gửi tự động mặc định: mở app không yêu cầu GPS', () async {
    var reads = 0;
    final service = LocationSharingService(
      locate: () async {
        reads++;
        return point(DateTime.now());
      },
    );
    addTearDown(service.dispose);
    expect(await service.autoShareIfNeeded(1), isNull);
    expect(reads, 0);
  });

  test(
    'Gửi tọa độ và địa chỉ, bật thông báo phụ huynh cho lần gửi thủ công',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['latitude'], 21.02867);
          expect(body['address'], 'Khu vực hồ Hoàn Kiếm, Hà Nội');
          expect(body['notifyParents'], isTrue);
          expect(body['source'], 'GPS');
          return http.Response('{}', 200);
        }),
      );
      final service = LocationSharingService(
        api: api,
        locate: () async => point(DateTime.now()),
        reverseGeocode: (_, _) async => 'Khu vực hồ Hoàn Kiếm, Hà Nội',
        authenticate: () async => true,
      );
      addTearDown(service.dispose);
      await service.share(1);
      expect(
        (await service.lastShared(1))?.address,
        'Khu vực hồ Hoàn Kiếm, Hà Nội',
      );
    },
  );

  test(
    'Không tra được địa chỉ vẫn gửi GPS; lỗi backend không ghi là đã gửi',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect((jsonDecode(request.body) as Map)['address'], isNull);
          return http.Response('{"message":"Unavailable"}', 503);
        }),
      );
      final service = LocationSharingService(
        api: api,
        locate: () async => point(DateTime.now()),
        reverseGeocode: (_, _) async => null,
        authenticate: () async => true,
      );
      addTearDown(service.dispose);
      await expectLater(service.share(1), throwsA(isA<ApiException>()));
      expect(await service.lastShared(1), isNull);
    },
  );

  test('Không dùng vị trí cũ hơn 10 phút để giả làm GPS hiện tại', () {
    final now = DateTime.now();
    expect(
      LocationSharingService.usableCache(
        point(now.subtract(const Duration(minutes: 5))),
        now,
      ),
      isTrue,
    );
    expect(
      LocationSharingService.usableCache(
        point(now.subtract(const Duration(minutes: 11))),
        now,
      ),
      isFalse,
    );
  });
}
