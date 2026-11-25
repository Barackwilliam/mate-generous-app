import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../theme/palette.dart';

/// The Latin cross used as the app's mark and icon.
class CrossIcon extends StatelessWidget {
  const CrossIcon({super.key, this.size = 24, this.color, this.outline = false});
  final double size;
  final Color? color;
  final bool outline;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _CrossPainter(color ?? IconTheme.of(context).color ?? Colors.white, outline),
      );
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.color, this.outline);
  final Color color;
  final bool outline;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final path = Path()
      ..moveTo(10.6 * u, 2 * u)
      ..lineTo(13.4 * u, 2 * u)
      ..lineTo(13.4 * u, 7.6 * u)
      ..lineTo(19 * u, 7.6 * u)
      ..lineTo(19 * u, 10.4 * u)
      ..lineTo(13.4 * u, 10.4 * u)
      ..lineTo(13.4 * u, 22 * u)
      ..lineTo(10.6 * u, 22 * u)
      ..lineTo(10.6 * u, 10.4 * u)
      ..lineTo(5 * u, 10.4 * u)
      ..lineTo(5 * u, 7.6 * u)
      ..lineTo(10.6 * u, 7.6 * u)
      ..close();
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = outline ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 1.6 * u
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color || old.outline != outline;
}

/// A cross on a hill against dawn light: "joy comes in the morning".
class DawnCrossArt extends StatelessWidget {
  const DawnCrossArt({super.key, this.height = 200, this.crossLight = false, this.crossX = 0.66});
  final double height;
  final bool crossLight; // light cross (player cover) vs. silhouette (home hero)
  final double crossX;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _DawnPainter(crossLight, crossX)),
      );
}

class _DawnPainter extends CustomPainter {
  _DawnPainter(this.crossLight, this.crossX);
  final bool crossLight;
  final double crossX;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF121A44), Color(0xFF2C2A5C), Color(0xFFA2643A)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    // Stars
    final star = Paint()..color = const Color(0xFFF7E3B0);
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.45), 0.6 + rnd.nextDouble() * 0.9, star);
    }
    final cx = s.width * crossX;
    final horizon = s.height * 0.68;
    // Glow
    final glowRect = Rect.fromCircle(center: Offset(cx, horizon), radius: s.height * 0.55);
    canvas.drawCircle(
      glowRect.center,
      glowRect.width / 2,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFD98A).withValues(alpha: 0.75),
          const Color(0xFFFFD98A).withValues(alpha: 0),
        ]).createShader(glowRect),
    );
    // Rays
    final ray = Paint()
      ..color = const Color(0xFFFFE2A3).withValues(alpha: 0.32)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final top = Offset(cx, horizon - s.height * 0.22);
    for (final a in [-90.0, -125.0, -55.0, -155.0, -25.0]) {
      final r = a * math.pi / 180;
      canvas.drawLine(top, top + Offset(math.cos(r), math.sin(r)) * s.height * 0.42, ray);
    }
    // Hill
    final hill = Path()
      ..moveTo(0, s.height * 0.86)
      ..quadraticBezierTo(s.width * 0.32, s.height * 0.71, cx, horizon)
      ..quadraticBezierTo(s.width * 0.86, s.height * 0.68, s.width, s.height * 0.76)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF0D1330));
    // Cross
    final h = s.height * 0.34;
    final w = h * 0.12;
    final cross = Paint()..color = crossLight ? const Color(0xFFF7E3B0) : Palette.night;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, horizon - h, w, h + 4), const Radius.circular(1.5)), cross);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - h * 0.3, horizon - h * 0.76, h * 0.6, w), const Radius.circular(1.5)), cross);
    // Foreground
    final front = Path()
      ..moveTo(0, s.height * 0.93)
      ..quadraticBezierTo(s.width * 0.26, s.height * 0.84, s.width * 0.5, s.height * 0.89)
      ..quadraticBezierTo(s.width * 0.74, s.height * 0.95, s.width, s.height * 0.88)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF080C1E));
  }

  @override
  bool shouldRepaint(_DawnPainter old) => old.crossLight != crossLight || old.crossX != crossX;
}

/// Category styling: its accent colour and icon, both set by the admin.
class CategoryStyle {
  CategoryStyle(this.accent, this.iconKey);
  final Color accent;
  final String iconKey;

  factory CategoryStyle.of(CategoryRef c) => CategoryStyle(parseHex(c.accentHex, Palette.gold), c.icon);

  Widget icon({double size = 24, Color? color}) {
    final c = color ?? accent;
    if (iconKey == 'cross') return CrossIcon(size: size, color: c);
    return Icon(_icons[iconKey] ?? Icons.auto_stories_outlined, size: size, color: c);
  }

  static const _icons = {
    'sunrise': Icons.wb_twilight_outlined,
    'heart': Icons.favorite_border_rounded,
    'family': Icons.family_restroom_outlined,
    'book': Icons.menu_book_outlined,
    'eye': Icons.visibility_outlined,
    'mic': Icons.mic_none_rounded,
    'people': Icons.groups_outlined,
    'hands': Icons.volunteer_activism_outlined,
    'school': Icons.school_outlined,
  };
}

/// Pictures that ship inside the app (assets/images).
class Img {
  static const splash = 'assets/images/splash.webp';
  static const heroHome = 'assets/images/hero_home.webp';
  static const audioCover = 'assets/images/audio_cover.webp';
  static const readerBanner = 'assets/images/reader_banner.webp';
  static const loginBanner = 'assets/images/login_banner.webp';
  static const empty = 'assets/images/empty.webp';
  static const loading = 'assets/images/loading.webp';
  static const offline = 'assets/images/offline.webp';
  static const premium = 'assets/images/premium_badge.webp';
  static const prayerIcon = 'assets/images/icon_prayer.webp';
  static const logo = 'assets/images/logo.webp';
}

/// How a department looks in the template: its glossy icon, tile colours,
/// and the picture used when an item has no cover of its own.
class DeptLook {
  const DeptLook(this.icon, this.colors, this.picture, this.cover);
  final String icon;
  final List<Color> colors;
  final String picture;
  final String cover;

  static const _byIcon = <String, DeptLook>{
    'cross': DeptLook('icon_bible_study', [Color(0xFFFFC93C), Color(0xFFE08A00)], Img.heroHome, 'assets/images/cover_kesha.webp'),
    'sunrise': DeptLook('icon_morning', [Color(0xFFFF9F43), Color(0xFFE8590C)], Img.loginBanner, 'assets/images/cover_kuanza_upya.webp'),
    'heart': DeptLook('icon_weary', [Color(0xFF3B82F6), Color(0xFF1E40AF)], 'assets/images/cover_kuanza_upya.webp', 'assets/images/cover_kuanza_upya.webp'),
    'family': DeptLook('icon_family', [Color(0xFFEC4899), Color(0xFFA21CAF)], 'assets/images/cover_ndoa.webp', 'assets/images/cover_ndoa.webp'),
    'eye': DeptLook('icon_prophecy', [Color(0xFF8B5CF6), Color(0xFF5B21B6)], 'assets/images/cover_danieli.webp', 'assets/images/cover_danieli.webp'),
    'mic': DeptLook('icon_sermons', [Color(0xFF22C55E), Color(0xFF15803D)], Img.audioCover, 'assets/images/cover_kesha.webp'),
    'people': DeptLook('icon_leadership', [Color(0xFF3B82F6), Color(0xFF1D4ED8)], Img.offline, 'assets/images/cover_kesha.webp'),
    'hands': DeptLook('icon_prayer', [Color(0xFF84CC16), Color(0xFF3F6212)], Img.splash, 'assets/images/cover_kesha.webp'),
    'books': DeptLook('icon_books', [Color(0xFFB7791F), Color(0xFF7C4A12)], Img.readerBanner, 'assets/images/cover_danieli.webp'),
    'school': DeptLook('icon_courses', [Color(0xFF2563EB), Color(0xFF1E3A8A)], Img.readerBanner, 'assets/images/cover_kesha.webp'),
    'bible': DeptLook('icon_bible_study', [Color(0xFF14B8A6), Color(0xFF0F766E)], Img.readerBanner, 'assets/images/cover_kesha.webp'),
  };

  static const fallback = DeptLook('icon_more', [Color(0xFF7C3AED), Color(0xFF4C1D95)], Img.offline, 'assets/images/cover_kesha.webp');

  static DeptLook of(CategoryRef c) => _byIcon[c.icon] ?? fallback;

  String get iconPath => 'assets/images/$icon.webp';
}

/// An image from the server (cached on the phone) or, when there is none or it
/// fails, a picture from the app itself.
class AppImage extends StatelessWidget {
  const AppImage({super.key, this.url, required this.fallback, this.fit = BoxFit.cover, this.width, this.height, this.alignment = Alignment.center});
  final String? url;
  final String fallback;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final local = Image.asset(fallback, fit: fit, width: width, height: height, alignment: alignment, gaplessPlayback: true);
    if (url == null || url!.isEmpty) return local;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      placeholder: (_, _) => local,
      errorWidget: (_, _, _) => local,
      fadeInDuration: const Duration(milliseconds: 200),
    );
  }
}
