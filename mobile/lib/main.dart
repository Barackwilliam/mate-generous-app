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
import 'state/app_state.dart';
import 'theme/palette.dart';
import 'widgets/art.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mategenerous.audio',
    androidNotificationChannelName: 'Mate Generous',
    androidNotificationOngoing: true,
  );
  final api = ApiClient();
  final state = AppState(api);
  await state.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider(create: (_) => AudioController(api)),
    ],
    child: const MateGenerousApp(),
  ));
}

class MateGenerousApp extends StatelessWidget {
  const MateGenerousApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((a) => a.themeMode);
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(Palette.light, Brightness.light),
      darkTheme: AppTheme.of(Palette.dark, Brightness.dark),
      themeMode: mode,
      home: const RootShell(),
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
      (s.home, CrossIcon(size: 22, color: p.faint, outline: true), CrossIcon(size: 22, color: p.accentText)),
      (s.explore, Icon(Icons.grid_view_outlined, color: p.faint), Icon(Icons.grid_view_rounded, color: p.accentText)),
      (s.listen, Icon(Icons.headphones_outlined, color: p.faint), Icon(Icons.headphones_rounded, color: p.accentText)),
      (s.library, Icon(Icons.bookmark_border_rounded, color: p.faint), Icon(Icons.bookmark_rounded, color: p.accentText)),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const MiniPlayer(),
        Container(
          decoration: BoxDecoration(color: p.nav, border: Border(top: BorderSide(color: p.border))),
          child: SafeArea(
            top: false,
            child: Semantics(
              label: s.mainMenu,
              child: SizedBox(
                height: 66,
                child: Row(children: [
                  for (final (i, (label, icon, active)) in items.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _index == i,
                        child: InkWell(
                          onTap: () => setState(() => _index = i),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _index == i ? active : icon,
                            const SizedBox(height: 4),
                            Text(label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _index == i ? FontWeight.w700 : FontWeight.w600,
                                  color: _index == i ? p.accentText : p.faint,
                                )),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
