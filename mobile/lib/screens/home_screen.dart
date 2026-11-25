import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../audio/audio_controller.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';
import 'category_screen.dart';
import 'listen_screen.dart';
import '../widgets/shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenExplore});
  final VoidCallback? onOpenExplore;

  Future<(HomeData, List<Category>)> _load(BuildContext context) async {
    final api = context.read<AppState>().api;
    final r = await Future.wait([api.home(), api.categories()]);
    return (r[0] as HomeData, r[1] as List<Category>);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final user = context.select<AppState, AppUser?>((a) => a.user);
    final now = DateTime.now();
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppTopBar(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.longDate(now), style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(user == null ? s.greeting(now.hour) : '${s.greeting(now.hour)}, ${user.firstName}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        ]),
      ),
    ]);
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
          child: LiveData<(HomeData, List<Category>)>(
            load: () => _load(context),
            loading: Column(children: [header, const Expanded(child: Loading())]),
            builder: (context, value, reload) {
              final (data, categories) = value;
              final depts = categories.where((c) => !c.isFlagship).toList();
              return RefreshIndicator(
                color: p.accent,
                onRefresh: reload,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    header,
                    if (data.tonight != null)
                      TonightCard(item: data.tonight!)
                    else
                      EmptyState(message: s.emptyHome),
                    for (final section in data.sections.where((x) => x.kind == 'continue_reading')) _ContinueCard(section: section),
                    if (depts.isNotEmpty) ...[
                      SectionHeader(title: s.discover, action: s.seeAll, onAction: onOpenExplore),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: depts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => SelectChip(
                            label: depts[i].label(s.en),
                            selected: false,
                            onTap: () => push(context, CategoryScreen.forCategory(depts[i])),
                          ),
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
      ),
    );
  }
}

/// Tonight's Message, as in the template: full picture, gold label, serif
/// title, verse, and the READ / LISTEN pills.
class TonightCard extends StatelessWidget {
  const TonightCard({super.key, required this.item});
  final ContentDetail item;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: p.border, width: 1.2),
          boxShadow: [BoxShadow(color: const Color(0xFF3B2A9C).withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: AppImage(url: item.coverImage, fallback: Img.heroHome, alignment: const Alignment(0.4, 0))),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE60B1033), Color(0x990B1033), Color(0x000B1033)],
                  stops: [0.0, 0.5, 0.95],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000B1033), Color(0xCC0B1033)],
                  stops: [0.45, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(99)),
                child: Text(item.category.label(s.en),
                    style: TextStyle(color: p.onAccent, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 60),
              Text(item.title,
                  style: const TextStyle(
                    fontFamily: AppTheme.serif,
                    fontWeight: FontWeight.w600,
                    fontSize: 30,
                    height: 1.12,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  )),
              if (item.scriptureReference.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.scriptureReference,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ],
              if (item.scriptureText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('“${item.scriptureText}”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, fontSize: 15.5, height: 1.45, color: Colors.white)),
              ],
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: [
                PrimaryButton(
                  height: 48,
                  label: s.read(item.readMinutes),
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
                  onPressed: () => openReader(context, item.slug),
                ),
                if (item.hasAudio && !item.isLocked)
                  Theme(
                    data: Theme.of(context).copyWith(extensions: [Palette.dark]),
                    child: SecondaryButton(
                      height: 48,
                      gold: true,
                      label: s.listenFor(item.audioLength),
                      icon: const Icon(Icons.headphones_rounded, size: 20),
                      onPressed: () {
                        context.read<AudioController>().play(item);
                        push(context, const ListenScreen());
                      },
                    ),
                  ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openReader(context, item.slug),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ItemArt(category: item.category, imageUrl: item.coverImage, size: 56, width: 64, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.continueReading} · ${item.category.label(s.en).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.accentText, letterSpacing: 0.8)),
                  const SizedBox(height: 5),
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                ]),
              ),
              Icon(Icons.play_circle_fill_rounded, color: p.accent, size: 34),
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
        height: isSeries ? 200 : 196,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: isSeries ? section.series.length : section.items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            if (!isSeries) return ContentShelfCard(item: section.items[i]);
            final x = section.series[i];
            return BookCover(series: x, onTap: () => push(context, CategoryScreen.forSeries(x)));
          },
        ),
      ),
    ]);
  }
}

/// A series shown as a book cover with its title in gold, as in My Library.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.series, required this.onTap, this.width = 128, this.height = 190});
  final SeriesInfo series;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: series.title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(6), right: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(3, 5))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            AppImage(url: series.coverImage, fallback: DeptLook.of(series.category).cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC000000)],
                  stops: [0.5, 1],
                ),
              ),
            ),
            const Positioned(left: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: Color(0x55000000))),
            Positioned(
              left: 10,
              right: 8,
              bottom: 10,
              child: Text(series.title,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.serif,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: Color(0xFFFFE08A),
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}
