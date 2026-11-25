import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';
import '../widgets/shell.dart';
import 'auth_screen.dart';
import 'category_screen.dart';
import 'home_screen.dart' show BookCover;

/// My Library, as in the template: stats, tabs, and books as covers.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final app = context.watch<AppState>();
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppTopBar(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        child: Text(s.myLibrary, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
    ]);

    if (!app.isSignedIn) {
      return Scaffold(
        body: NightBackground(
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
              header,
              StateCard(
                image: Img.empty,
                icon: const Icon(Icons.bookmarks_rounded),
                title: s.myLibrary,
                subtitle: s.libraryGuest,
                action: s.signInOrUp,
                onAction: () => push(context, const AuthScreen()),
              ),
              _Books(owned: const [], title: s.booksAndSeries),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
          child: LiveData<LibraryData>(
            watchKey: app.user?.email,
            load: () => app.api.library(),
            loading: Column(children: [header, const Expanded(child: Loading())]),
            builder: (context, lib, reload) {
              final tabs = [s.history, s.bookmark, s.favourite, s.mine];
              return RefreshIndicator(
                color: p.accent,
                onRefresh: reload,
                child: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.border)),
                      child: Row(children: [
                        _Stat(icon: Icons.menu_book_rounded, value: lib.streak, label: s.nights, color: p.text),
                        _Stat(icon: Icons.verified_rounded, value: lib.completedCount, label: s.lessons, color: const Color(0xFF38BDF8)),
                        _Stat(icon: Icons.favorite_rounded, value: lib.savedCount, label: s.favourites, color: p.text),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(children: [
                      for (final (i, t) in tabs.indexed)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _tab == i,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _tab = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                height: 42,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _tab == i ? p.surfaceHi : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _tab == i ? p.border : Colors.transparent),
                                ),
                                child: Text(t,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w600, color: _tab == i ? p.text : p.muted)),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  _Books(owned: lib.ownedSeries, title: lib.ownedSeries.isEmpty ? s.booksAndSeries : s.myBooks),
                  ..._tabBody(context, lib),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _tabBody(BuildContext context, LibraryData lib) {
    final s = context.s;
    final p = context.pal;
    final pad = <Widget>[const SizedBox(height: 8)];
    switch (_tab) {
      case 0:
        if (lib.history.isEmpty) return [EmptyState(message: s.emptyHistory)];
        return [
          ...pad,
          for (final h in lib.history)
            ContentRow(
              item: h.content,
              trailing: h.completed
                  ? Icon(Icons.check_circle_rounded, color: p.accentText, semanticLabel: s.finished)
                  : SizedBox(
                      width: 64,
                      child: Row(children: [
                        Expanded(child: ThinProgress(value: h.percent / 100)),
                        const SizedBox(width: 6),
                        Text('${h.percent}%', style: TextStyle(fontSize: 11, color: p.muted, fontWeight: FontWeight.w700)),
                      ]),
                    ),
            ),
        ];
      case 1:
        return lib.bookmarks.isEmpty ? [EmptyState(message: s.emptySaved)] : [...pad, for (final c in lib.bookmarks) ContentRow(item: c)];
      case 2:
        return lib.favourites.isEmpty ? [EmptyState(message: s.emptyFavourites)] : [...pad, for (final c in lib.favourites) ContentRow(item: c)];
      default:
        return lib.owned.isEmpty && lib.ownedSeries.isEmpty
            ? [EmptyState(message: s.emptyOwned)]
            : [...pad, for (final c in lib.owned) ContentRow(item: c)];
    }
  }
}

/// "My Books": owned books, or (until there are any) the series to discover.
class _Books extends StatelessWidget {
  const _Books({required this.owned, required this.title});
  final List<SeriesInfo> owned;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Widget shelf(List<SeriesInfo> list) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: title, action: s.seeAllArrow, onAction: () => push(context, const _AllSeries())),
            SizedBox(
              height: 172,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => BookCover(
                  series: list[i],
                  width: 112,
                  height: 164,
                  onTap: () => push(context, CategoryScreen.forSeries(list[i])),
                ),
              ),
            ),
          ]);
    if (owned.isNotEmpty) return shelf(owned);
    return LiveData<List<SeriesInfo>>(
      load: () => context.read<AppState>().api.series(),
      loading: const SizedBox.shrink(),
      builder: (context, list, _) => shelf(list),
    );
  }
}

class _AllSeries extends StatelessWidget {
  const _AllSeries();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Row(children: [
                RoundButton(icon: const Icon(Icons.arrow_back_rounded), label: s.back, bare: true, onTap: () => Navigator.pop(context)),
                Expanded(child: Text(s.booksAndSeries, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              ]),
            ),
            Expanded(
              child: LiveData<List<SeriesInfo>>(
                load: () => context.read<AppState>().api.series(),
                builder: (context, list, _) => GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.66,
                  children: [
                    for (final x in list)
                      BookCover(series: x, width: double.infinity, height: double.infinity, onTap: () => push(context, CategoryScreen.forSeries(x))),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12.5, color: context.pal.muted, fontWeight: FontWeight.w600)),
        ]),
      );
}
