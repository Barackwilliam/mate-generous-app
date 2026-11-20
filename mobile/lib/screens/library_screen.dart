import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'auth_screen.dart';
import 'category_screen.dart';

/// My Library: reading stats, history, saved, favourites and what the user owns.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<LibraryData>? _future;
  bool _wasSignedIn = false;
  int _tab = 0;

  void _load() => _future = context.read<AppState>().api.library();

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final app = context.watch<AppState>();
    if (app.isSignedIn && (!_wasSignedIn || _future == null)) _load();
    _wasSignedIn = app.isSignedIn;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(children: [
        Expanded(child: Text(s.myLibrary, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
        const LangToggle(),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: s.account,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => push(context, const AccountScreen()),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: p.accent,
              child: app.user == null
                  ? Icon(Icons.person_rounded, color: p.onAccent)
                  : Text(app.user!.initials, style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]),
    );

    if (!app.isSignedIn) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            header,
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bookmarks_outlined, size: 48, color: p.accentText),
                    const SizedBox(height: 14),
                    Text(s.libraryGuest, textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.5)),
                    const SizedBox(height: 20),
                    PrimaryButton(label: s.signInOrUp, onPressed: () => push(context, const AuthScreen())),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<LibraryData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return Column(children: [header, const Expanded(child: Loading())]);
            if (snap.hasError) return Column(children: [header, Expanded(child: ErrorRetry(error: snap.error!, onRetry: _refresh))]);
            final lib = snap.data!;
            final tabs = [s.history, s.bookmark, s.favourite, s.mine];
            return RefreshIndicator(
              color: p.accent,
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(children: [
                    _Stat(value: lib.streak, label: s.streak, highlight: true),
                    const SizedBox(width: 10),
                    _Stat(value: lib.completedCount, label: s.completed),
                    const SizedBox(width: 10),
                    _Stat(value: lib.savedCount, label: s.saved),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
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
                                duration: const Duration(milliseconds: 180),
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: _tab == i ? p.chipOn : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                                child: Text(t,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w600, color: _tab == i ? p.chipOnText : p.muted)),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                ..._tabBody(context, lib),
              ]),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _tabBody(BuildContext context, LibraryData lib) {
    final s = context.s;
    final p = context.pal;
    switch (_tab) {
      case 0:
        if (lib.history.isEmpty) return [EmptyState(message: s.emptyHistory)];
        return [
          for (final h in lib.history)
            ContentRow(
              item: h.content,
              trailing: h.completed
                  ? Text('✓ ${s.finished}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.accentText))
                  : SizedBox(
                      width: 64,
                      child: Row(children: [
                        Expanded(child: ThinProgress(value: h.percent / 100, color: CategoryStyle.of(h.content.category).accent)),
                        const SizedBox(width: 6),
                        Text('${h.percent}%', style: TextStyle(fontSize: 11, color: p.muted, fontWeight: FontWeight.w600)),
                      ]),
                    ),
            ),
        ];
      case 1:
        return lib.bookmarks.isEmpty ? [EmptyState(message: s.emptySaved)] : [for (final c in lib.bookmarks) ContentRow(item: c)];
      case 2:
        return lib.favourites.isEmpty ? [EmptyState(message: s.emptyFavourites)] : [for (final c in lib.favourites) ContentRow(item: c)];
      default:
        if (lib.owned.isEmpty && lib.ownedSeries.isEmpty) return [EmptyState(message: s.emptyOwned)];
        return [
          if (lib.ownedSeries.isNotEmpty)
            SizedBox(
              height: 170,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                scrollDirection: Axis.horizontal,
                itemCount: lib.ownedSeries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _BookCover(series: lib.ownedSeries[i]),
              ),
            ),
          for (final c in lib.owned) ContentRow(item: c),
        ];
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.highlight = false});
  final int value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: highlight ? p.accentText : p.text)),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.series});
  final SeriesInfo series;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final accent = CategoryStyle.of(series.category).accent;
    return InkWell(
      onTap: () => push(context, CategoryScreen.forSeries(series)),
      child: Container(
        width: 106,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.tint(accent),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(16)),
          border: Border(left: BorderSide(color: Color.lerp(p.tint(accent), Colors.black, 0.35)!, width: 6)),
        ),
        alignment: Alignment.bottomLeft,
        child: Text(series.title,
            style: TextStyle(fontFamily: AppTheme.serif, fontSize: 15, fontWeight: FontWeight.w600, height: 1.2, color: p.onTint(accent))),
      ),
    );
  }
}
