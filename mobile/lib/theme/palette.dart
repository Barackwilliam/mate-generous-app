import 'package:material_ui/material_ui.dart';

/// The approved template: deep night blue-violet, bright gold, glowing cards.
/// Dark is the app's look; Light is the cream "paper" of the reader by day.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.nav,
    required this.chipOn,
    required this.chipOnText,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHi;
  final Color border;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent; // fills: buttons, badges
  final Color accentText; // accent used as text on bg (passes contrast)
  final Color onAccent;
  final Color nav;
  final Color chipOn;
  final Color chipOnText;

  static const gold = Color(0xFFFFC23D);
  static const goldDeep = Color(0xFFF59E0B);
  static const night = Color(0xFF0B1033);
  static const violet = Color(0xFF2A1466);
  static const green = Color(0xFF1F7A3E);

  /// Gold buttons and badges.
  static const goldGradient = LinearGradient(colors: [Color(0xFFFFD45C), Color(0xFFF5A623)]);

  /// The night sky behind every dark screen.
  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1033), Color(0xFF110E3C), Color(0xFF0B1033)],
  );

  static const dark = Palette(
    bg: night,
    surface: Color(0xFF141B4D),
    surfaceHi: Color(0xFF1B2462),
    border: Color(0xFF2E3C8F),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFBAC2EA),
    faint: Color(0xFF8F98CC),
    accent: gold,
    accentText: gold,
    onAccent: Color(0xFF1A1033),
    nav: Color(0xFF0E1544),
    chipOn: gold,
    chipOnText: Color(0xFF1A1033),
  );

  static const light = Palette(
    bg: Color(0xFFFBF3E1),
    surface: Color(0xFFF5E7C6),
    surfaceHi: Color(0xFFEFDDB3),
    border: Color(0xFFE6D3A8),
    text: Color(0xFF1E1B2E),
    muted: Color(0xFF5C5468),
    faint: Color(0xFF6B6376),
    accent: gold,
    accentText: Color(0xFF8A5A0B),
    onAccent: Color(0xFF1A1033),
    nav: Color(0xFFF6EAD0),
    chipOn: gold,
    chipOnText: Color(0xFF1A1033),
  );

  /// A soft tile colour for a category accent (used for cards and tiles).
  Color tint(Color accent) => Color.lerp(bg, accent, identical(this, dark) ? 0.2 : 0.28)!;
  Color onTint(Color accent) =>
      identical(this, dark) ? Color.lerp(accent, Colors.white, 0.65)! : Color.lerp(accent, Colors.black, 0.62)!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

class AppTheme {
  static const sans = 'PlusJakartaSans';
  static const serif = 'Lora';

  static ThemeData of(Palette p, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: Palette.gold, brightness: b).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.bg,
      onSurface: p.text,
      outline: p.border,
    );
    final base = ThemeData(brightness: b, useMaterial3: true, colorScheme: scheme, fontFamily: sans);
    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      extensions: [p],
      appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.text, elevation: 0, scrolledUnderElevation: 0),
      dividerColor: p.border,
      textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text, fontFamily: sans),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.bg, fontFamily: sans, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: identical(p, Palette.dark) ? const Color(0xFFFFF4DA) : p.accentText,
        overlayColor: p.accent.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: TextStyle(color: p.muted),
        hintStyle: TextStyle(color: p.faint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.accent, width: 1.5)),
      ),
    );
  }
}
