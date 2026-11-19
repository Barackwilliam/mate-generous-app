import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mate_generous/api/api_client.dart';
import 'package:mate_generous/main.dart';
import 'package:mate_generous/screens/reader_screen.dart';
import 'package:mate_generous/state/app_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> card(String slug, String title, {bool locked = false}) => {
      'id': slug.hashCode,
      'slug': slug,
      'title': title,
      'category': {'id': 1, 'name': 'Kesha la Usiku', 'slug': 'kesha-la-usiku'},
      'series': null,
      'author': null,
      'cover_image': null,
      'scripture_reference': 'Zaburi 30:5',
      'summary': 'Muhtasari',
      'has_audio': false,
      'access_level': locked ? 'subscriber' : 'free',
      'is_locked': locked,
    };

Map<String, dynamic> detail(String slug, String title, {bool locked = false}) => {
      ...card(slug, title, locked: locked),
      'scripture_text': 'Kilio huweza kuja usiku, lakini asubuhi huwa furaha.',
      'body': locked ? null : '<p>Mwili wa ujumbe.</p>',
      'application': locked ? null : 'Mtafute Mungu leo.',
      'prayer': locked ? null : 'Bwana, nipe tumaini.',
      'preview': locked ? 'Kipande cha bure.' : null,
      'navigation': {'previous': null, 'next': {'slug': 'kesho', 'title': 'Ujumbe wa Kesho'}},
      'share': {'excerpt': 'Kipande', 'url': 'https://example.com/m/$slug'},
    };

ApiClient fakeApi() => ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((req) async {
        final path = req.url.path;
        Object body;
        if (path == '/api/home/') {
          body = {
            'tonight': detail('leo', 'Usiku wa Matumaini'),
            'sections': [
              {'title': 'Jumbe za karibuni', 'kind': 'latest', 'items': [card('jana', 'Ujumbe wa Jana')]},
            ],
          };
        } else if (path == '/api/contents/leo/') {
          body = detail('leo', 'Usiku wa Matumaini');
        } else if (path == '/api/contents/funge/') {
          body = detail('funge', 'Ujumbe wa Wanachama', locked: true);
        } else {
          return http.Response('{"detail":"Not found"}', 404);
        }
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

Future<AppState> appState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(fakeApi());
  await state.load();
  return state;
}

void main() {
  testWidgets('home shows Tonight\'s Message and admin sections', (tester) async {
    final state = await appState();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const MateGenerousApp()));
    await tester.pumpAndSettle();

    expect(find.text('UJUMBE WA USIKU HUU'), findsOneWidget);
    expect(find.text('Usiku wa Matumaini'), findsOneWidget);
    expect(find.text('SOMA'), findsOneWidget);
    expect(find.text('Jumbe za karibuni'), findsOneWidget);
    expect(find.text('Ujumbe wa Jana'), findsOneWidget);
  });

  Future<void> openReader(WidgetTester tester, String slug) async {
    final state = await appState();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: ReaderScreen(slug: slug)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('reader shows scripture, prayer and next item', (tester) async {
    await openReader(tester, 'leo');
    expect(find.text('Zaburi 30:5'), findsOneWidget);
    expect(find.text('Sala'), findsOneWidget);
    expect(find.text('Matumizi ya vitendo'), findsOneWidget);
    expect(find.text('Ujumbe wa Kesho'), findsOneWidget);
  });

  testWidgets('locked item shows preview and join prompt, not the text', (tester) async {
    await openReader(tester, 'funge');
    expect(find.text('Kipande cha bure.'), findsOneWidget);
    expect(find.text('Ujumbe huu ni kwa wanachama.'), findsOneWidget);
    expect(find.text('Sala'), findsNothing);
    expect(find.text('Ingia au jisajili'), findsOneWidget);
  });

  testWidgets('bookmarking asks a visitor to sign in', (tester) async {
    await openReader(tester, 'leo');
    await tester.tap(find.byTooltip('Alamisho'));
    await tester.pumpAndSettle();
    expect(find.text('Barua pepe au namba ya simu'), findsOneWidget);
  });

  test('font size stays within limits and is remembered', () async {
    final state = await appState();
    await state.setFontScale(5);
    expect(state.fontScale, AppState.maxFont);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('fontScale'), AppState.maxFont);
  });
}
