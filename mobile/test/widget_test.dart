import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mate_generous/api/api_client.dart';
import 'package:mate_generous/api/cache_store.dart';
import 'package:mate_generous/audio/audio_controller.dart';
import 'package:mate_generous/main.dart';
import 'package:mate_generous/screens/account_screen.dart';
import 'package:mate_generous/screens/auth_screen.dart';
import 'package:mate_generous/screens/plans_screen.dart';
import 'package:mate_generous/screens/reader_screen.dart';
import 'package:mate_generous/state/app_state.dart';
import 'package:mate_generous/theme/palette.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kesha = {'id': 1, 'name': 'Kesha la Usiku', 'name_en': 'Kesha la Usiku', 'slug': 'kesha-la-usiku', 'icon': 'cross', 'accent_color': '#F5B544'};
const unabii = {'id': 2, 'name': 'Unabii', 'name_en': 'Prophecy', 'slug': 'unabii', 'icon': 'eye', 'accent_color': '#FFB0B8'};

Map<String, dynamic> card(String slug, String title, {String access = 'free', bool locked = false, Map cat = kesha}) => {
      'id': slug.hashCode,
      'slug': slug,
      'title': title,
      'kind': 'devotional',
      'category': cat,
      'series': null,
      'author': {'name': 'Mate Generous'},
      'cover_image': null,
      'scripture_reference': 'Zaburi 30:5',
      'summary': 'Muhtasari',
      'has_audio': false,
      'access_level': access,
      'is_locked': locked,
      'read_minutes': 6,
      'publish_at': DateTime.now().toIso8601String(),
    };

Map<String, dynamic> detail(String slug, String title, {String access = 'free', bool locked = false}) => {
      ...card(slug, title, access: access, locked: locked),
      'scripture_text': 'Kilio huweza kuja kukaa usiku, lakini asubuhi huwa furaha.',
      'body': locked ? null : '<p>Mwili wa ujumbe.</p><h2>Usiku una mwisho</h2>',
      'application': locked ? null : 'Mtafute Mungu leo.',
      'prayer': locked ? null : 'Bwana, nipe tumaini.',
      'preview': locked ? 'Kipande cha bure.' : null,
      'navigation': {'previous': null, 'next': {'slug': 'kesho', 'title': 'Nuru Gizani'}},
      'share': {'excerpt': 'Kipande', 'url': 'https://example.com/m/$slug'},
    };

final routes = <String, Object>{
  '/api/home/': {
    'tonight': detail('leo', 'Kilio Hudumu Usiku Mmoja'),
    'sections': [
      {'title': 'Jumbe za karibuni', 'kind': 'latest', 'items': [card('jana', 'Mungu wa Saa Nne')]},
    ],
  },
  '/api/categories/': [
    {...kesha, 'description': 'Ibada ya kila usiku', 'is_flagship': true},
    {...unabii, 'description': 'Danieli na Ufunuo', 'is_flagship': false},
  ],
  '/api/topics/': [
    {'name': 'Tumaini', 'slug': 'tumaini'},
  ],
  '/api/contents/leo/': detail('leo', 'Kilio Hudumu Usiku Mmoja'),
  '/api/contents/funge/': detail('funge', 'Nuru Gizani', access: 'premium', locked: true),
  '/api/subscriptions/plans/': [
    {'id': 1, 'name': 'Mwezi 1', 'tier': 'standard', 'duration_days': 30, 'price': '5000'},
    {'id': 2, 'name': 'Mwaka 1', 'tier': 'standard', 'duration_days': 365, 'price': '0'},
  ],
};

int requests = 0;

ApiClient fakeApi({CacheStore? cache, bool offline = false}) => ApiClient(
      baseUrl: 'https://api.test',
      cache: cache ?? MemoryCacheStore(),
      client: MockClient((req) async {
        requests++;
        if (offline) throw http.ClientException('no network');
        final body = routes[req.url.path];
        if (body == null) return http.Response('{"detail":"Not found"}', 404);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

Future<AppState> appState({String lang = 'sw'}) async {
  SharedPreferences.setMockInitialValues({'lang': lang});
  final state = AppState(fakeApi());
  await state.load();
  return state;
}

Widget wrap(AppState state, Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider(create: (_) => AudioController(state.api)),
      ],
      child: child,
    );

Widget page(AppState state, Widget screen) => wrap(
      state,
      MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.of(Palette.dark, Brightness.dark), home: screen),
    );

/// A tall phone-width screen so whole pages are laid out without scrolling.
void tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 2200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets("home shows Tonight's Message, sections and the menu", (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(wrap(state, const MateGenerousApp()));
    await tester.pumpAndSettle();

    expect(find.text('Kesha la Usiku'), findsWidgets);
    expect(find.text('Kilio Hudumu Usiku Mmoja'), findsOneWidget);
    expect(find.text('Soma · dk 6'), findsOneWidget);
    expect(find.text('Zaburi 30:5'), findsWidgets);
    expect(find.text('Jumbe za karibuni'), findsOneWidget);
    expect(find.text('Nyumbani'), findsOneWidget);
    expect(find.text('Maktaba'), findsOneWidget);
  });

  testWidgets('SW/EN switch changes the whole app and is remembered', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(wrap(state, const MateGenerousApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EN').first);
    await tester.pumpAndSettle();
    expect(find.text('Good evening').evaluate().isNotEmpty || find.text('Good morning').evaluate().isNotEmpty || find.text('Good afternoon').evaluate().isNotEmpty, isTrue);
    expect(find.text('Read · 6 min'), findsOneWidget);
    expect(find.text('Latest messages'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Prophecy'), findsOneWidget); // category name in English
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lang'), 'en');
  });

  testWidgets('reader shows scripture, application, prayer and next', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(page(state, const ReaderScreen(slug: 'leo')));
    await tester.pumpAndSettle();
    expect(find.text('– Zaburi 30:5 –'), findsOneWidget);
    expect(find.text('Matumizi ya vitendo'), findsOneWidget);
    expect(find.text('Sala'), findsOneWidget);
    expect(find.text('Nuru Gizani'), findsOneWidget);
  });

  testWidgets('locked premium item shows only the preview and how to unlock', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(page(state, const ReaderScreen(slug: 'funge')));
    await tester.pumpAndSettle();
    expect(find.text('Kipande cha bure.'), findsOneWidget);
    expect(find.text('Ujumbe huu ni kwa wanachama wa Premium.'), findsOneWidget);
    expect(find.text('Sala'), findsNothing);
    expect(find.text('Ingia au jisajili'), findsOneWidget);
  });

  testWidgets('saving as a visitor opens sign in', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(page(state, const ReaderScreen(slug: 'leo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hifadhi'));
    await tester.pumpAndSettle();
    expect(find.text('Barua pepe au namba ya simu'), findsOneWidget);
    expect(find.text('Karibu tena!'), findsOneWidget);
  });

  testWidgets('explore lists the flagship first, then departments and topics', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(wrap(state, const MateGenerousApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makundi'));
    await tester.pumpAndSettle();
    expect(find.text('Gundua'), findsWidgets);
    expect(find.text('Kesha la Usiku'), findsWidgets);
    expect(find.text('Unabii'), findsWidgets);
    expect(find.text('Tumaini'), findsOneWidget);
  });

  testWidgets('library asks a visitor to sign in', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(wrap(state, const MateGenerousApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maktaba'));
    await tester.pumpAndSettle();
    expect(find.text('Maktaba Yangu'), findsWidgets);
    expect(find.text('Ingia au jisajili'), findsOneWidget);
  });

  testWidgets('plans show prices, "price soon" for unpriced plans, and no payment yet', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await tester.pumpWidget(page(state, const PlansScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Tsh 5,000'), findsOneWidget);
    expect(find.text('Bei inakuja'), findsOneWidget);
    expect(find.text('BEST VALUE'), findsOneWidget);
    expect(find.text('Tsh 0'), findsOneWidget);
    await tester.tap(find.text('Jiunge Sasa'));
    await tester.pumpAndSettle();
    expect(find.text('Malipo yanakuja hivi karibuni'), findsOneWidget);
  });

  testWidgets('light theme renders the reader on cream paper', (tester) async {
    tallPhone(tester);
    final state = await appState();
    await state.setThemeMode(ThemeMode.light);
    await tester.pumpWidget(wrap(
      state,
      MaterialApp(theme: AppTheme.of(Palette.light, Brightness.light), home: const ReaderScreen(slug: 'leo')),
    ));
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor ?? Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor,
        Palette.light.bg);
  });

  for (final lang in ['sw', 'en']) {
    testWidgets('every screen fits a small 360px phone in $lang', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final state = await appState(lang: lang);
      for (final screen in <Widget>[
        const ReaderScreen(slug: 'leo'),
        const ReaderScreen(slug: 'funge'),
        const PlansScreen(),
        const AuthScreen(),
        const AccountScreen(),
      ]) {
        await tester.pumpWidget(page(state, screen));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(wrap(state, const MateGenerousApp()));
      await tester.pumpAndSettle();
      for (final tab in lang == 'en' ? ['Explore', 'Listen', 'Library'] : ['Makundi', 'Sikiliza', 'Maktaba']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('offline-first: a saved copy is served when the server is unreachable', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = MemoryCacheStore();
    await fakeApi(cache: cache).home(); // first run online: saved on the phone
    final offline = fakeApi(cache: cache, offline: true);
    final home = await offline.home();
    expect(home.tonight!.title, 'Kilio Hudumu Usiku Mmoja');
  });

  test('prefetch downloads home, departments and every message for offline reading', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = MemoryCacheStore();
    routes['/api/contents/'] = {'next': null, 'results': [card('leo', 'Kilio Hudumu Usiku Mmoja'), card('funge', 'Nuru Gizani')]};
    routes['/api/series/'] = {'next': null, 'results': []};
    await fakeApi(cache: cache).prefetch();
    final offline = fakeApi(cache: cache, offline: true);
    expect((await offline.categories()).length, 2);
    expect((await offline.content('funge')).title, 'Nuru Gizani');
    expect((await offline.content('leo')).prayer, isNotNull);
  });

  test('a saved copy shows at once, and a newer server answer is announced', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = MemoryCacheStore();
    final api = fakeApi(cache: cache);
    await api.categories();
    await cache.write('g:categories/', '[]'); // pretend the saved copy is old
    final fresh = fakeApi(cache: cache);
    var ticks = 0;
    fresh.revision.addListener(() => ticks++);
    expect(await fresh.categories(), isEmpty); // instant, from the phone
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ticks, 1); // background refresh found the newer list
    expect((await fresh.categories()).length, 2);
  });

  test('font size stays within limits and is remembered', () async {
    final state = await appState();
    await state.setFontScale(5);
    expect(state.fontScale, AppState.maxFont);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('fontScale'), AppState.maxFont);
  });
}
