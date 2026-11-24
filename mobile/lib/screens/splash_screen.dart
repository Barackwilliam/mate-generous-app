import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';

/// The opening screen: loads saved settings, starts the background download,
/// and shows the dove-and-cross picture while it does.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    await Future.wait([
      app.load(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    app.syncInBackground();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => widget.next,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      backgroundColor: Palette.night,
      body: Stack(fit: StackFit.expand, children: [
        Image.asset(Img.splash, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x000B1033), Color(0x330B1033), Color(0xEE0B1033)],
              stops: [0.0, 0.45, 0.85],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFF5A623)]).createShader(r),
                child: const Text('Mate\nGenerous',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppTheme.serif, fontSize: 52, height: 1.0, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Text(s.libraryLine, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const Text('- Tanzania -', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 18),
              Text(s.tagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, color: Colors.white, fontSize: 18, height: 1.35)),
              const SizedBox(height: 26),
              const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.6, color: Palette.gold)),
            ]),
          ),
        ),
      ]),
    );
  }
}
