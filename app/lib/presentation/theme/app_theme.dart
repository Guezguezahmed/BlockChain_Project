import 'package:flutter/material.dart';

/// Calm teal / slate look — Apple-soft materials, not purple-gradient AI clichés.
class AppTheme {
  static const Color _ink = Color(0xFF0F1C1A);
  static const Color _panel = Color(0xFF16302C);
  static const Color _accent = Color(0xFF2DD4A8);
  static const Color _accentDim = Color(0xFF1A9B7A);
  static const Color _sand = Color(0xFFE7F2EE);
  static const Color _shell = Color(0xFFF4FAF7);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // System typography (SF on iOS) — avoid forcing Roboto.
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentDim,
        brightness: Brightness.light,
        primary: _accentDim,
        surface: _sand,
      ),
      scaffoldBackgroundColor: _sand,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: _ink,
        displayColor: _ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _shell.withValues(alpha: 0.72),
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: _sand,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: BorderSide(color: _ink.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.62),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _ink.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accentDim, width: 1.4),
        ),
      ),
      cardColor: Colors.white.withValues(alpha: 0.45),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accent,
        foregroundColor: _ink,
        elevation: 2,
        shape: CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _shell.withValues(alpha: 0.82),
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: _ink.withValues(alpha: 0.28),
        dragHandleColor: const Color(0xFF9BB5AD),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: _shell.withValues(alpha: 0.72),
        elevation: 0,
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Soft sand sibling used by sheets / bottom bar (same family as [_sand]).
  static Color get shellSurface => _shell;

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
  static Color get accentDim => _accentDim;
  static Color get ink => _ink;
  static Color get panel => _panel;
  static Color get sand => _sand;
}
