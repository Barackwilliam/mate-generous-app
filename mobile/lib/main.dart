import 'package:just_audio_background/just_audio_background.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'audio/audio_controller.dart';
import 'config.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/listen_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme/palette.dart';
import 'widgets/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mategenerous.audio',
    androidNotificationChannelName: 'Kesha la Usiku',
    androidNotificationOngoing: true,
  );
  final api = ApiClient();
  final state = AppState(api);
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider(create: (_) => AudioController(api)),
    ],
    child: const MateGenerousApp(showSplash: true),
  ));
}

class MateGenerousApp extends StatelessWidget {
  const MateGenerousApp({super.key, this.showSplash = false});
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((a) => a.themeMode);
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(Palette.light, Brightness.light),
      darkTheme: AppTheme.of(Palette.dark, Brightness.dark),
      themeMode: mode,
      home: showSplash ? const SplashScreen(next: RootShell()) : const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _scaffold = GlobalKey<ScaffoldState>();

  void _goToTab(int i) {
    if (_scaffold.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final pages = [
      HomeScreen(onOpenExplore: () => setState(() => _index = 1)),
      const ExploreScreen(),
      const ListenTab(),
      const LibraryScreen(),
    ];
    final items = [
      (s.home, Icons.home_outlined, Icons.home_rounded),
      (s.explore, Icons.grid_view_outlined, Icons.grid_view_rounded),
      (s.listen, Icons.headphones_outlined, Icons.headphones_rounded),
      (s.library, Icons.menu_book_outlined, Icons.menu_book_rounded),
    ];
    return Scaffold(
      key: _scaffold,
      extendBody: true,
      drawer: AppDrawer(currentTab: _index, onTab: _goToTab),
      body: ShellScope(
        openMenu: () => _scaffold.currentState?.openDrawer(),
        goToTab: _goToTab,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const MiniPlayer(),
            Container(
              height: 74,
              decoration: BoxDecoration(
                color: p.nav,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.accent.withValues(alpha: 0.55), width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Semantics(
                label: s.mainMenu,
                child: Row(children: [
                  for (final (i, (label, icon, active)) in items.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _index == i,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => setState(() => _index = i),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_index == i ? active : icon, color: _index == i ? p.accentText : p.muted, size: 26),
                            const SizedBox(height: 2),
                            Text(label,
                                maxLines: 1,
                                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _index == i ? FontWeight.w800 : FontWeight.w600,
                                  color: _index == i ? p.accentText : p.muted,
                                )),
                            const SizedBox(height: 3),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 3,
                              width: _index == i ? 26 : 0,
                              decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(2)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
