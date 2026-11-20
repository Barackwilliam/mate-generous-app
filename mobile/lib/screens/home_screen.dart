import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../audio/audio_controller.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'category_screen.dart';
import 'listen_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenExplore});
  final VoidCallback? onOpenExplore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(HomeData, List<Category>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(HomeData, List<Category>)> _load() async {
    final api = context.read<AppState>().api;
    final results = await Future.wait([api.home(), api.categories()]);
    return (results[0] as HomeData, results[1] as List<Category>);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final user = context.select<AppState, AppUser?>((a) => a.user);
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(HomeData, List<Category>)>(
          future: _future,
          builder: (context, snap) {
            final header = Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.longDate(now), style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w500))),
                  const LangToggle(),
                  const SizedBox(width: 8),
                  RoundButton(icon: const Icon(Icons.search_rounded), label: s.search, onTap: () => push(context, const SearchScreen())),
                ]),
                const SizedBox(height: 6),
                Text(user == null ? s.greeting(now.hour) : '${s.greeting(now.hour)}, ${user.firstName}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              ]),
            );
            if (snap.connectionState != ConnectionState.done) return Column(children: [header, const Expanded(child: Loading())]);
            if (snap.hasError) return Column(children: [header, Expanded(child: ErrorRetry(error: snap.error!, onRetry: _reload))]);
            final (data, categories) = snap.data!;
            return RefreshIndicator(
              color: p.accent,
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  header,
                  if (data.tonight != null) TonightCard(item: data.tonight!) else EmptyState(message: s.emptyHome),
                  for (final section in data.sections.where((x) => x.kind == 'continue_reading')) _ContinueCard(section: section),
                  if (categories.isNotEmpty) ...[
                    SectionHeader(title: s.discover, action: s.seeAll, onAction: widget.onOpenExplore),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.where((c) => !c.isFlagship).length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final c = categories.where((c) => !c.isFlagship).elementAt(i);
                          return SelectChip(
                            label: c.label(s.en),
                            selected: i == 0,
                            onTap: () => push(context, CategoryScreen.forCategory(c)),
                          );
                        },
                      ),
                    ),
                  ],
                  for (final section in data.sections.where((x) => x.kind != 'continue_reading')) _Section(section: section),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tonight's Message: dawn-and-cross art, title, verse, READ and LISTEN.
class TonightCard extends StatelessWidget {
  const TonightCard({super.key, required this.item});
  final ContentDetail item;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: identical(p, Palette.dark) ? const Color(0xFF131B3D) : p.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            item.coverImage != null
                ? Image.network(item.coverImage!, height: 200, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DawnCrossArt(height: 200))
                : const DawnCrossArt(height: 200),
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(99)),
                child: Text(s.tonightBadge,
                    style: TextStyle(color: p.onAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  style: const TextStyle(fontFamily: AppTheme.serif, fontWeight: FontWeight.w600, fontSize: 26, height: 1.2)),
              if (item.scriptureReference.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(children: [
                    if (item.scriptureText.isNotEmpty) TextSpan(text: '“${item.scriptureText}” '),
                    TextSpan(
                      text: '— ${item.scriptureReference}',
                      style: TextStyle(fontFamily: AppTheme.sans, fontStyle: FontStyle.normal, fontSize: 13, fontWeight: FontWeight.w600, color: p.accentText),
                    ),
                  ]),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, fontSize: 15, height: 1.55, color: p.muted),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: PrimaryButton(
                    height: 50,
                    label: s.read(item.readMinutes),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    onPressed: () => openReader(context, item.slug),
                  ),
                ),
                if (item.hasAudio && !item.isLocked) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      height: 50,
                      label: s.listenFor(item.audioLength),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      onPressed: () {
                        context.read<AudioController>().play(item);
                        push(context, const ListenScreen());
                      },
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.section});
  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    if (section.items.isEmpty) return const SizedBox.shrink();
    final item = section.items.first;
    final p = context.pal;
    final s = context.s;
    final accent = CategoryStyle.of(item.category).accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openReader(context, item.slug),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ItemArt(category: item.category, imageUrl: item.coverImage, size: 54, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.continueReading} · ${item.category.label(s.en).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.muted, letterSpacing: 0.8)),
                  const SizedBox(height: 5),
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: identical(p, Palette.dark) ? accent : p.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});
  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final isSeries = section.kind == 'series_list';
    if (isSeries ? section.series.isEmpty : section.items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: s.section(section.kind, section.title),
        action: section.categorySlug != null ? s.seeAll : null,
        onAction: section.categorySlug == null
            ? null
            : () => push(context, CategoryScreen(slug: section.categorySlug!, title: section.title)),
      ),
      SizedBox(
        height: isSeries ? 120 : 190,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: isSeries ? section.series.length : section.items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            if (!isSeries) return ContentShelfCard(item: section.items[i]);
            final x = section.series[i];
            return ColourTile(
              width: 164,
              title: x.title,
              subtitle: '${x.category.label(s.en)}${x.itemCount != null ? ' · ${x.itemCount}' : ''}',
              category: x.category,
              onTap: () => push(context, CategoryScreen.forSeries(x)),
            );
          },
        ),
      ),
    ]);
  }
}
