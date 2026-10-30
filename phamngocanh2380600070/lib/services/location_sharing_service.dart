import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import 'api_service.dart';
import 'child_auth_service.dart';

class SharedLocation {
  const SharedLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.address,
    this.cached = false,
  });
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? accuracy;
  final String? address;
  final bool cached;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'accuracyMeters': accuracy,
    'address': address,
    'cached': cached,
  };
  factory SharedLocation.fromJson(Map data) => SharedLocation(
    latitude: (data['latitude'] as num).toDouble(),
    longitude: (data['longitude'] as num).toDouble(),
    recordedAt: DateTime.parse(data['recordedAt'] as String),
    accuracy: (data['accuracyMeters'] as num?)?.toDouble(),
    address: data['address'] as String?,
    cached: data['cached'] == true,
  );
}

class LocationSharingService {
  LocationSharingService({
    ApiService? api,
    Future<Position> Function()? locate,
    Future<String?> Function(double, double)? reverseGeocode,
    Future<bool> Function()? authenticate,
  }) : _api = api ?? ApiService(),
       _locate = locate ?? currentPosition,
       _reverse = reverseGeocode ?? addressFor,
       _authenticate = authenticate ?? ChildAuthService().refreshToken;
  final ApiService _api;
  final Future<Position> Function() _locate;
  final Future<String?> Function(double, double) _reverse;
  final Future<bool> Function() _authenticate;
  static const _storage = FlutterSecureStorage();
  static const _channel = MethodChannel('kidguard/guard');
  static final Map<String, String> _addressCache = {};

  static Future<String?> addressFor(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    if (_addressCache.containsKey(key)) return _addressCache[key];
    try {
      final address = await _channel
          .invokeMethod<String>('reverseGeocode', {
            'latitude': latitude,
            'longitude': longitude,
          })
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      final value = address?.trim();
      if (value != null && value.isNotEmpty) {
        if (_addressCache.length > 100) _addressCache.clear();
        _addressCache[key] = value;
        return value;
      }
    } catch (_) {
      /* Coordinates and map remain available if Android cannot resolve an address. */
    }
    return null;
  }

  static bool usableCache(Position position, DateTime now) {
    final age = now.toUtc().difference(position.timestamp.toUtc());
    return age >= const Duration(minutes: -1) &&
        age <= const Duration(minutes: 10) &&
        position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude.abs() <= 90 &&
        position.longitude.abs() <= 180;
  }

  static Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException(
        'GPS đang tắt. Bật vị trí trên điện thoại rồi thử lại.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Quyền vị trí đã bị tắt. Mở cài đặt ứng dụng và cho phép vị trí khi dùng app.',
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const ApiException('Chưa được cấp quyền vị trí.');
    }
    bool emulator = false;
    try {
      emulator =
          (await _channel.invokeMapMethod<String, dynamic>(
            'status',
          ))?['emulator'] ==
          true;
    } catch (_) {}
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: emulator
            ? AndroidSettings(
                forceLocationManager: true,
                accuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 15),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
      );
    } on TimeoutException {
      final cached = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: emulator,
      );
      if (cached != null && usableCache(cached, DateTime.now())) return cached;
      throw const ApiException(
        'Chưa lấy được vị trí. Kiểm tra GPS rồi thử lại.',
      );
    }
  }

  Future<bool> autoEnabled(int deviceId) async =>
      await _storage.read(key: 'kidguard_auto_location_$deviceId') == 'true';
  Future<void> setAutoEnabled(int deviceId, bool enabled) => _storage.write(
    key: 'kidguard_auto_location_$deviceId',
    value: '$enabled',
  );
  Future<SharedLocation?> lastShared(int deviceId) async {
    try {
      final json = await _storage.read(key: 'kidguard_last_location_$deviceId');
      return json == null
          ? null
          : SharedLocation.fromJson(jsonDecode(json) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<SharedLocation?> autoShareIfNeeded(int deviceId) async {
    if (!await autoEnabled(deviceId)) return null;
    final last = DateTime.tryParse(
      await _storage.read(key: 'kidguard_location_sent_at_$deviceId') ?? '',
    );
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 15)) {
      return null;
    }
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    return share(deviceId, automatic: true);
  }

  Future<SharedLocation> share(
    int deviceId, {
    bool automatic = false,

    void Function(SharedLocation)? onLocated,
  }) async {
    if (deviceId <= 0) throw const ApiException('Thiết bị chưa được ghép.');
    final position = await _locate();
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      throw const ApiException('GPS trả về tọa độ không hợp lệ.');
    }
    final address = await _reverse(position.latitude, position.longitude);
    final location = SharedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: position.timestamp,
      accuracy: position.accuracy.isFinite && position.accuracy >= 0
          ? position.accuracy
          : null,
      address: address,
      cached:
          DateTime.now().difference(position.timestamp) >
          const Duration(minutes: 1),
    );
    onLocated?.call(location);
    if (!await _authenticate()) {
      throw const ApiException(
        'Phiên thiết bị không hợp lệ. Hãy đăng nhập lại.',
      );
    }
    await _api.post(
      'Locations/sync',
      body: {
        'deviceId': deviceId,
        ...location.toJson(),
        'notifyParents': !automatic,
        'address': address?.substring(0, address.length.clamp(0, 350)),
        'source': location.cached ? 'CACHED' : 'GPS',
      },
    );
    await _storage.write(
      key: 'kidguard_last_location_$deviceId',
      value: jsonEncode(location.toJson()),
    );
    await _storage.write(
      key: 'kidguard_location_sent_at_$deviceId',
      value: DateTime.now().toUtc().toIso8601String(),
    );
    return location;
  }

  void dispose() => _api.dispose();
}
