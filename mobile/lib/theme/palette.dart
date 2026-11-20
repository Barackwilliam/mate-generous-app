import 'package:material_ui/material_ui.dart';

/// "Nuru ya Msalaba": night blue with the warm gold of dawn light.
/// Dark is the default; Light is the cream "paper" the reader uses by day.
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

  static const gold = Color(0xFFF5B544);
  static const night = Color(0xFF0A0F24);

  static const dark = Palette(
    bg: night,
    surface: Color(0xFF121937),
    surfaceHi: Color(0xFF1A2147),
    border: Color(0xFF222B4D),
    text: Color(0xFFF3F1EA),
    muted: Color(0xFFA3ABCB),
    faint: Color(0xFF8C94B8),
    accent: gold,
    accentText: gold,
    onAccent: night,
    nav: Color(0xFF0D1330),
    chipOn: Color(0xFFF3F1EA),
    chipOnText: night,
  );

  static const light = Palette(
    bg: Color(0xFFFBF7EE),
    surface: Color(0xFFF3EBD9),
    surfaceHi: Color(0xFFEDE2C9),
    border: Color(0xFFE4D7BC),
    text: Color(0xFF22201B),
    muted: Color(0xFF5F5A4F),
    faint: Color(0xFF6B6556),
    accent: gold,
    accentText: Color(0xFF8A5A0B),
    onAccent: night,
    nav: Color(0xFFF6F0E2),
    chipOn: Color(0xFF22201B),
    chipOnText: Color(0xFFFBF7EE),
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
