import 'package:material_ui/material_ui.dart';

/// Night blue and warm gold: the colours of Kesha la Usiku.
class AppTheme {
  static const night = Color(0xFF14213D);
  static const gold = Color(0xFFE0A526);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: night,
      brightness: brightness,
      secondary: gold,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(centerTitle: false, backgroundColor: scheme.surface, scrolledUnderElevation: 0),
      cardTheme: CardThemeData(clipBehavior: Clip.antiAlias, elevation: 0, color: scheme.surfaceContainerHighest.withValues(alpha: 0.5)),
    );
  }
}
