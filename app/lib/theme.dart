import 'package:flutter/material.dart';

/// Soft, calm palette in the spirit of Nara: warm cream background, deep ink text,
/// one pastel per activity.
class Palette {
  static const background = Color(0xFFFBF6F0);
  static const surface = Colors.white;
  static const ink = Color(0xFF2E3A4B);
  static const muted = Color(0xFF8A8F98);
  static const line = Color(0xFFEDE6DD);
  static const accent = Color(0xFF3F5B7A);
  static const danger = Color(0xFFC75B4A);
}

/// Look of each kind of record.
class Kind {
  const Kind(this.label, this.icon, this.color, this.deep);
  final String label;
  final IconData icon;
  final Color color; // pastel fill
  final Color deep; // icon / text on the pastel

  static const breast = Kind('Nursing', Icons.favorite_rounded, Color(0xFFF9D5CC), Color(0xFFC4604A));
  static const bottle = Kind('Bottle', Icons.local_drink_rounded, Color(0xFFFBE3C4), Color(0xFFB9772A));
  static const solids = Kind('Solids', Icons.restaurant_rounded, Color(0xFFF4E6B8), Color(0xFF9C7E1E));
  static const sleep = Kind('Sleep', Icons.bedtime_rounded, Color(0xFFD8DDF5), Color(0xFF5162A8));
  static const diaper = Kind('Diaper', Icons.baby_changing_station_rounded, Color(0xFFD3EBDD), Color(0xFF3E8A62));
  static const pump = Kind('Pump', Icons.water_drop_rounded, Color(0xFFF1D6E6), Color(0xFFA34D7F));
  static const growth = Kind('Growth', Icons.straighten_rounded, Color(0xFFD5ECEC), Color(0xFF2F8383));
  static const health = Kind('Health', Icons.medical_services_rounded, Color(0xFFF6D9D9), Color(0xFFB04848));
  static const activity = Kind('Activity', Icons.wb_sunny_rounded, Color(0xFFE2E9D0), Color(0xFF66803A));
  static const milestone = Kind('Milestone', Icons.star_rounded, Color(0xFFE8DDF4), Color(0xFF7653A8));
  static const note = Kind('Note', Icons.edit_note_rounded, Color(0xFFEAE6E0), Color(0xFF6E6559));

  /// Look of an event (feeds are split by method).
  static Kind of(String type, [String? method]) {
    switch (type) {
      case 'feed':
        return method == 'bottle'
            ? bottle
            : method == 'solids'
            ? solids
            : breast;
      case 'sleep':
        return sleep;
      case 'diaper':
        return diaper;
      case 'pump':
        return pump;
      case 'growth':
        return growth;
      case 'health':
        return health;
      case 'activity':
        return activity;
      case 'milestone':
        return milestone;
      default:
        return note;
    }
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.accent, surface: Palette.surface, primary: Palette.accent, error: Palette.danger);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: Palette.background);
  final text = base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.background,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Palette.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.surface,
      indicatorColor: const Color(0xFFE6ECF3),
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: Palette.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.line),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Palette.surface,
      side: const BorderSide(color: Palette.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: Palette.ink),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.background,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
