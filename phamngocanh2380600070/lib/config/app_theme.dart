import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData from({required Color background}) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6254D9),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? scheme.surfaceContainerHighest
            : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static ThemeData get light => from(background: const Color(0xFFF7F8FC));
}
