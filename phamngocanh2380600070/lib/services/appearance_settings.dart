import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _fontKey = 'kidguard_font_scale';
  static const _colorKey = 'kidguard_bg_color';

  static const backgrounds = <Color>[
    Color(0xFFF7F8FC),
    Color(0xFFFFF8E7),
    Color(0xFFE8F5F0),
    Color(0xFFEAF2FF),
    Color(0xFF1C1B2E),
  ];

  final FlutterSecureStorage _storage;
  double fontScale = 1;
  Color background = backgrounds.first;
  bool loaded = false;

  Future<void> load() async {
    final scale = double.tryParse(await _storage.read(key: _fontKey) ?? '');
    final color = int.tryParse(
      await _storage.read(key: _colorKey) ?? '',
      radix: 16,
    );
    if (scale != null) {
      fontScale = scale < 0.95
          ? 0.9
          : scale > 1.1
          ? 1.2
          : 1;
    }
    if (color != null) {
      background = Color(color);
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value;
    await _storage.write(key: _fontKey, value: value.toString());
    notifyListeners();
  }

  Future<void> setBackground(Color color) async {
    background = color;
    await _storage.write(
      key: _colorKey,
      value: color.toARGB32().toRadixString(16),
    );
    notifyListeners();
  }
}
