import 'package:flutter/services.dart';

import '../config/api_config.dart';

class GuardService {
  static const _channel = MethodChannel('kidguard/guard');

  static Future<Map<String, dynamic>> status() async =>
      Map<String, dynamic>.from(await _channel.invokeMapMethod('status') ?? {});

  static Future<void> configure({
    required String token,
    required int deviceId,
    required String identifier,
    required String secret,
  }) async {
    ApiConfig.endpoint('ScreenTime/sync');
    await _channel.invokeMethod('configure', {
      'baseUrl': ApiConfig.baseUrl,
      'token': token,
      'deviceId': deviceId,
      'identifier': identifier,
      'secret': secret,
    });
  }

  static Future<void> enable() =>
      _channel.invokeMethod('enable', {'enabled': true});
  static Future<void> openSettings(String type) =>
      _channel.invokeMethod('${type}Settings');
  static Future<void> sync() => _channel.invokeMethod('sync');
  static Future<Map<String, dynamic>> usageSnapshot() async =>
      Map<String, dynamic>.from(
        await _channel.invokeMapMethod('usageSnapshot') ?? {},
      );
}
