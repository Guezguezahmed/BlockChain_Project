import 'package:flutter/material.dart';

/// Calm teal / slate look — avoids purple-gradient AI clichés.
class AppTheme {
  static const Color _ink = Color(0xFF0F1C1A);
  static const Color _panel = Color(0xFF16302C);
  static const Color _accent = Color(0xFF2DD4A8);
  static const Color _accentDim = Color(0xFF1A9B7A);
  static const Color _sand = Color(0xFFE7F2EE);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentDim,
        brightness: Brightness.light,
        primary: _accentDim,
        surface: _sand,
      ),
      scaffoldBackgroundColor: _sand,
      fontFamily: 'Roboto', // overridden below via textTheme only if needed
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: _sand,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _ink),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      cardColor: Colors.white.withValues(alpha: 0.55),
    );
  }

  static LinearGradient get heroGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0F1C1A),
          Color(0xFF16302C),
          Color(0xFF1A4A40),
        ],
      );

  static Color get accent => _accent;
  static Color get ink => _ink;
  static Color get panel => _panel;
}
