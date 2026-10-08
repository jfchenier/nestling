import 'package:flutter/material.dart';

/// Calm dark palette in the spirit of Nara: deep navy, soft pastel band per activity,
/// serif display type.
class Palette {
  static const background = Color(0xFF1D2030);
  static const surface = Color(0xFF2A2E3D); // cards
  static const raised = Color(0xFF343949); // inputs, sheets, dialogs
  static const line = Color(0xFF3E4354);
  static const ink = Color(0xFFEEEAE3); // text on dark
  static const muted = Color(0xFFA3A7B3);
  static const bandInk = Color(0xFF1D2030); // text on pastel bands
  static const accent = Color(0xFF4F6E9E); // round + buttons, selected toggles
  static const accentLight = Color(0xFF8FA9D1);
  static const danger = Color(0xFFE5806F);
  static const nav = Color(0xFF171A27);
}

/// Serif family for titles and big numbers (Libre Caslon Text, bundled).
const serif = 'Caslon';

TextStyle serifStyle(double size, {Color color = Palette.ink, FontWeight weight = FontWeight.w400, double? height}) =>
    TextStyle(fontFamily: serif, fontSize: size, color: color, fontWeight: weight, height: height, letterSpacing: -0.2);

/// Look of each kind of record: label, line icon and the pastel band color.
class Kind {
  const Kind(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  /// Accent on dark backgrounds (the band color reads well on navy).
  Color get deep => color;

  static const breast = Kind('Nursing', Icons.favorite_border_rounded, Color(0xFFF7C948));
  static const bottle = Kind('Bottle', Icons.local_drink_outlined, Color(0xFFF2DD9A));
  static const solids = Kind('Solids', Icons.restaurant_rounded, Color(0xFFF0AE68));
  static const combo = Kind('Combo', Icons.join_inner_rounded, Color(0xFFF7C948));
  static const sleep = Kind('Sleep', Icons.bedtime_outlined, Color(0xFFB7DCEB));
  static const diaper = Kind('Diaper', Icons.baby_changing_station_outlined, Color(0xFFEFE7D8));
  static const pump = Kind('Pump', Icons.water_drop_outlined, Color(0xFFF4A698));
  static const growth = Kind('Growth', Icons.straighten_rounded, Color(0xFFB5DB8E));
  static const health = Kind('Health', Icons.medical_services_outlined, Color(0xFFC7CBF3));
  static const activity = Kind('Activity', Icons.wb_sunny_outlined, Color(0xFFD6C4F2));
  static const milestone = Kind('Milestone', Icons.star_border_rounded, Color(0xFFA6DADF));
  static const note = Kind('Note', Icons.edit_note_rounded, Color(0xFFD9D4CC));

  /// Look of an event (feeds are split by method).
  static Kind of(String type, [String? method]) {
    switch (type) {
      case 'feed':
        return switch (method) {
          'bottle' => bottle,
          'solids' => solids,
          'combo' => combo,
          _ => breast,
        };
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
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.accent,
    brightness: Brightness.dark,
    surface: Palette.surface,
    primary: Palette.accentLight,
    onPrimary: Palette.bandInk,
    secondaryContainer: Palette.accent,
    onSecondaryContainer: Colors.white,
    error: Palette.danger,
    outline: Palette.line,
    outlineVariant: Palette.line,
    surfaceContainerHigh: Palette.raised,
    surfaceContainerHighest: Palette.raised,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: Palette.background);
  final text = base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  return base.copyWith(
    textTheme: text.copyWith(
      displayMedium: text.displayMedium?.copyWith(fontFamily: serif),
      headlineMedium: text.headlineMedium?.copyWith(fontFamily: serif),
      headlineSmall: text.headlineSmall?.copyWith(fontFamily: serif),
      titleLarge: text.titleLarge?.copyWith(fontFamily: serif),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.background,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serifStyle(28),
    ),
    cardTheme: CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.nav,
      indicatorColor: Palette.accent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Palette.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? Palette.ink : Palette.muted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.accent,
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
        side: const BorderSide(color: Palette.ink, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Palette.accentLight)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.raised,
      labelStyle: const TextStyle(color: Palette.muted),
      hintStyle: const TextStyle(color: Palette.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.accentLight, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Palette.surface,
      selectedColor: Palette.accent,
      side: const BorderSide(color: Palette.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: Palette.ink),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.accent : Palette.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Palette.ink),
        side: const WidgetStatePropertyAll(BorderSide(color: Palette.line)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Palette.ink),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.accent : Palette.line),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.raised,
      showDragHandle: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Palette.raised),
    popupMenuTheme: const PopupMenuThemeData(color: Palette.raised),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      contentTextStyle: TextStyle(color: Palette.bandInk),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Palette.muted, textColor: Palette.ink),
  );
}
