import 'package:flutter/material.dart';

class OrbitColors {
  OrbitColors._();

  static const primary = Color(0xFF5B6EF5);
  static const primaryDark = Color(0xFF3F51D8);
  static const danger = Color(0xFFEF4444);

  static const movie = Color(0xFF7C5CFC);
  static const canteen = Color(0xFFFF8A3D);
  static const study = Color(0xFF2DA4FF);
  static const gaming = Color(0xFF22C55E);
  static const sports = Color(0xFFFF5A7A);
  static const all = primary;

  static const bg = Color(0xFFF6F7FB);
  static const surface = Colors.white;
  static const ink = Color(0xFF1B1D28);
  static const inkSoft = Color(0xFF737892);
  static const line = Color(0xFFE9EBF3);
}

class OrbitTheme extends ThemeExtension<OrbitTheme> {
  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color line;

  const OrbitTheme({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.line,
  });

  static const light = OrbitTheme(
    bg: OrbitColors.bg,
    surface: OrbitColors.surface,
    ink: OrbitColors.ink,
    inkSoft: OrbitColors.inkSoft,
    line: OrbitColors.line,
  );

  static const dark = OrbitTheme(
    bg: Color(0xFF0F1117),
    surface: Color(0xFF191C24),
    ink: Color(0xFFF1F2F7),
    inkSoft: Color(0xFF9AA0B8),
    line: Color(0xFF2A2E3A),
  );

  @override
  OrbitTheme copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? inkSoft,
    Color? line,
  }) => OrbitTheme(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    line: line ?? this.line,
  );

  @override
  OrbitTheme lerp(ThemeExtension<OrbitTheme>? other, double t) {
    if (other is! OrbitTheme) return this;
    return OrbitTheme(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension OrbitContext on BuildContext {
  OrbitTheme get orbit => Theme.of(this).extension<OrbitTheme>() ?? OrbitTheme.light;
  Color get cBg => orbit.bg;
  Color get cSurface => orbit.surface;
  Color get cInk => orbit.ink;
  Color get cInkSoft => orbit.inkSoft;
  Color get cLine => orbit.line;
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

ThemeData buildOrbitTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final o = dark ? OrbitTheme.dark : OrbitTheme.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: OrbitColors.primary,
    brightness: brightness,
  ).copyWith(
    surface: o.surface,
    onSurface: o.ink,
    outline: o.line,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: o.bg,
    extensions: [o],
    appBarTheme: AppBarTheme(
      backgroundColor: o.bg,
      foregroundColor: o.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: o.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: o.ink),
    ),
    cardTheme: CardThemeData(
      color: o.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: o.line),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: o.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: o.surface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: o.surface,
      indicatorColor: OrbitColors.primary.withValues(alpha: 0.14),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? OrbitColors.primary : o.inkSoft,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? OrbitColors.primary : o.inkSoft,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: o.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: o.inkSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: o.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: o.line),
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: o.ink,
        side: BorderSide(color: o.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: OrbitColors.primary),
    ),
    dividerTheme: DividerThemeData(color: o.line, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2A2E3A) : OrbitColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(iconColor: o.inkSoft, textColor: o.ink),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: OrbitColors.primary,
    ),
  );
}
