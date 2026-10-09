import 'package:flutter/material.dart';

/// Nestling's own "nursery garden" palette: warm oat neutrals, a eucalyptus accent and
/// soft earthy pastels per activity (no baby pink / baby blue). Light and dark variants.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.muted,
    required this.bandInk,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.danger,
    required this.nav,
  });

  final Brightness brightness;
  final Color background; // page
  final Color surface; // cards
  final Color raised; // inputs, sheets, dialogs
  final Color line;
  final Color ink; // main text
  final Color muted;
  final Color bandInk; // text on pastel bands (dark in both modes)
  final Color accent; // buttons, + , selected toggles
  final Color onAccent;
  final Color accentSoft; // tinted panels, selection fills
  final Color danger;
  final Color nav;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F3EC),
    surface: Color(0xFFFFFDF8),
    raised: Color(0xFFEFE8DD),
    line: Color(0xFFE3DACB),
    ink: Color(0xFF2E2925),
    muted: Color(0xFF7C746A),
    bandInk: Color(0xFF2E2925),
    accent: Color(0xFF3D7A6A),
    onAccent: Colors.white,
    accentSoft: Color(0xFFDDEBE4),
    danger: Color(0xFFB4492F),
    nav: Color(0xFFFFFDF8),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF1B1A18),
    surface: Color(0xFF262421),
    raised: Color(0xFF322F2B),
    line: Color(0xFF3D3934),
    ink: Color(0xFFF0EAE1),
    muted: Color(0xFFA69E93),
    bandInk: Color(0xFFF0EAE1), // light text on the darker activity fills
    accent: Color(0xFF4E8F7C),
    onAccent: Colors.white,
    accentSoft: Color(0xFF2A3833),
    danger: Color(0xFFE59478),
    nav: Color(0xFF161513),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 || other == null ? this : other;
}

extension AppColorsX on BuildContext {
  AppColors get pal => Theme.of(this).extension<AppColors>()!;
}

/// Display text (titles, big numbers): the platform sans-serif (Roboto), bold and slightly tight.
/// No custom family, so it follows the theme on every platform.
const String? serif = null;

/// Title / big-number text; without [color] it inherits the surrounding text color (follows the theme).
TextStyle serifStyle(double size, {Color? color, FontWeight weight = FontWeight.w700, double? height}) =>
    TextStyle(fontFamily: serif, fontSize: size, color: color, fontWeight: weight, height: height, letterSpacing: size >= 20 ? -0.4 : 0);

/// Look of each kind of record: label, line icon, its pastel and a deep tone of the same hue.
class Kind {
  const Kind(this.label, this.icon, this.color, this.deepTone);
  final String label;
  final IconData icon;

  /// Pastel used for bands, blobs and chart fills (same in both themes).
  final Color color;

  /// Darker shade of the same hue, for text and marks on light backgrounds.
  final Color deepTone;

  /// Accent that reads well on the current background (text, chart marks).
  Color on(AppColors c) => c.isDark ? color : deepTone;

  /// Fill for bands, icon circles and chips: the pastel in light mode, a muted dark shade of the
  /// same hue in dark mode (text on it is `AppColors.bandInk`).
  Color fill(AppColors c) => c.isDark ? Color.lerp(deepTone, c.background, 0.45)! : color;

  /// Icon color on [fill].
  Color iconOn(AppColors c) => c.isDark ? color : deepTone;

  static const breast = Kind('Breastfeeding', Icons.favorite_rounded, Color(0xFFF5C4A1), Color(0xFFB0602D)); // apricot
  static const bottle = Kind('Bottle', Icons.local_drink_rounded, Color(0xFFF2DCA4), Color(0xFF94701C)); // honey
  static const solids = Kind('Solids', Icons.restaurant_rounded, Color(0xFFEFAE80), Color(0xFFA9532A)); // carrot
  static const combo = Kind('Combo', Icons.join_inner_rounded, Color(0xFFF5C4A1), Color(0xFFB0602D));
  static const sleep = Kind('Sleep', Icons.bedtime_rounded, Color(0xFFD4CBEA), Color(0xFF65529C)); // dusk lilac
  static const diaper = Kind('Diaper', Icons.baby_changing_station_rounded, Color(0xFFCADFBC), Color(0xFF4A763A)); // sage
  static const pump = Kind('Pump', Icons.water_drop_rounded, Color(0xFFEDE29B), Color(0xFF7E7116)); // butter
  static const growth = Kind('Growth', Icons.straighten_rounded, Color(0xFFE4D4BA), Color(0xFF7A5F3C)); // oat
  static const health = Kind('Health', Icons.medical_services_rounded, Color(0xFFCBD19A), Color(0xFF616B26)); // moss
  static const activity = Kind('Activity', Icons.wb_sunny_rounded, Color(0xFFB9E0D1), Color(0xFF2C755E)); // seafoam
  static const milestone = Kind('Milestone', Icons.star_rounded, Color(0xFFEBC46E), Color(0xFF8A6210)); // marigold
  static const note = Kind('Note', Icons.edit_note_rounded, Color(0xFFDDD6CC), Color(0xFF6B6359)); // stone

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

ThemeData buildTheme(AppColors c) {
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: c.brightness,
    surface: c.surface,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondaryContainer: c.accent,
    onSecondaryContainer: c.onAccent,
    error: c.danger,
    outline: c.line,
    outlineVariant: c.line,
    surfaceContainerHigh: c.raised,
    surfaceContainerHighest: c.raised,
    onSurface: c.ink,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: c.background, extensions: [c]);
  final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
  return base.copyWith(
    textTheme: text.copyWith(
      displayMedium: text.displayMedium?.copyWith(fontFamily: serif),
      headlineMedium: text.headlineMedium?.copyWith(fontFamily: serif),
      headlineSmall: text.headlineSmall?.copyWith(fontFamily: serif),
      titleLarge: text.titleLarge?.copyWith(fontFamily: serif),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serifStyle(28, color: c.ink),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: c.isDark ? BorderSide.none : BorderSide(color: c.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.nav,
      indicatorColor: c.accentSoft,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.accent : c.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? c.ink : c.muted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(64, 52),
        side: BorderSide(color: c.ink, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.accent)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      labelStyle: TextStyle(color: c.muted),
      hintStyle: TextStyle(color: c.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.surface,
      selectedColor: c.accent,
      side: BorderSide(color: c.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(fontWeight: FontWeight.w500, color: c.ink),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.ink),
        side: WidgetStatePropertyAll(BorderSide(color: c.line)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.raised),
      trackOutlineColor: WidgetStatePropertyAll(c.line),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.raised,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.raised),
    popupMenuTheme: PopupMenuThemeData(color: c.raised),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(color: c.background),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.muted, textColor: c.ink),
  );
}
