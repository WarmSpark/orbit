import 'package:flutter/material.dart';

class OrbitColors {
  OrbitColors._();

  static const primary = Color(0xFF5B6EF5);
  static const primaryDark = Color(0xFF3F51D8);
  static const bg = Color(0xFFF6F7FB);
  static const surface = Colors.white;
  static const ink = Color(0xFF1B1D28);
  static const inkSoft = Color(0xFF737892);
  static const line = Color(0xFFE9EBF3);
  static const danger = Color(0xFFEF4444);

  static const movie = Color(0xFF7C5CFC);
  static const canteen = Color(0xFFFF8A3D);
  static const study = Color(0xFF2DA4FF);
  static const gaming = Color(0xFF22C55E);
  static const sports = Color(0xFFFF5A7A);
  static const all = primary;
}

class HangoutCategory {
  final String key;
  final IconData icon;
  final Color color;
  const HangoutCategory(this.key, this.icon, this.color);
}

const List<HangoutCategory> kCategories = [
  HangoutCategory('Movie', Icons.movie_rounded, OrbitColors.movie),
  HangoutCategory('Canteen', Icons.local_cafe_rounded, OrbitColors.canteen),
  HangoutCategory('Study', Icons.menu_book_rounded, OrbitColors.study),
  HangoutCategory('Gaming', Icons.sports_esports_rounded, OrbitColors.gaming),
  HangoutCategory('Sports', Icons.sports_soccer_rounded, OrbitColors.sports),
];

HangoutCategory categoryFor(String key) => kCategories.firstWhere(
  (c) => c.key == key,
  orElse: () =>
      const HangoutCategory('All', Icons.grid_view_rounded, OrbitColors.all),
);

ThemeData buildOrbitTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OrbitColors.primary,
    brightness: Brightness.light,
  ).copyWith(surface: OrbitColors.surface);

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: OrbitColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: OrbitColors.bg,
      foregroundColor: OrbitColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: OrbitColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: OrbitColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: OrbitColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OrbitColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OrbitColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OrbitColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OrbitColors.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OrbitColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: OrbitColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: OrbitColors.line, space: 1),
  );
}
