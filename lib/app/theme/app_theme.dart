import 'package:flutter/material.dart';

/// Application themes derived from one restrained blue seed colour.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF3B6EF6);

  /// Light theme used when the platform requests a light appearance.
  static final ThemeData light = _build(Brightness.light);

  /// Dark theme used when the platform requests a dark appearance.
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: _inputBorder(scheme),
        enabledBorder: _inputBorder(scheme),
        focusedBorder: _inputBorder(scheme, color: scheme.primary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(ColorScheme scheme, {Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color ?? scheme.outlineVariant),
    );
  }
}
