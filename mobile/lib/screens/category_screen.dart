import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

/// One category (with its series as filter chips) or one series.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, this.slug, this.seriesSlug, required this.title, this.category, this.subtitle});

  factory CategoryScreen.forCategory(Category c) => CategoryScreen(slug: c.slug, title: c.name, category: c);
  factory CategoryScreen.forSeries(SeriesInfo s) =>
      CategoryScreen(seriesSlug: s.slug, title: s.title, category: s.category, subtitle: s.description);

  final String? slug;
  final String? seriesSlug;
  final String title;
  final CategoryRef? category;
  final String? subtitle;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<ContentCard>> _items;
  Future<List<SeriesInfo>>? _series;
  String? _seriesFilter;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.slug != null) _series = context.read<AppState>().api.series(category: widget.slug);
  }

  void _load() {
    _items = context.read<AppState>().api.contents(
          category: _seriesFilter == null ? widget.slug : null,
          series: _seriesFilter ?? widget.seriesSlug,
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final cat = widget.category;
    final title = cat != null && widget.seriesSlug == null ? cat.label(s.en) : widget.title;
    final about = widget.subtitle ?? (cat is Category ? cat.about(s.en) : '');
    final style = cat == null ? null : CategoryStyle.of(cat);
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        SizedBox(
          height: 300,
          child: Stack(fit: StackFit.expand, children: [
            if (cat is Category && cat.coverImage != null)
              Image.network(cat.coverImage!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const DawnCrossArt(height: 300, crossLight: true, crossX: 0.77))
            else
              const DawnCrossArt(height: 300, crossLight: true, crossX: 0.77),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC0A0F24)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(children: [
                    RoundButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), label: s.back, onImage: true, onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    const LangToggle(onImage: true),
                  ]),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.seriesSlug != null && cat != null)
                  Text(cat.label(s.en).toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: style?.accent ?? Palette.gold)),
                Text(title,
                    style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white, height: 1.15)),
                if (about.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(about, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFFC9CEE4))),
                ],
              ]),
            ),
          ]),
        ),
        if (_series != null)
          FutureBuilder<List<SeriesInfo>>(
            future: _series,
            builder: (context, snap) {
              final list = snap.data ?? const <SeriesInfo>[];
              if (list.isEmpty) return const SizedBox(height: 8);
              return SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  children: [
                    SelectChip(label: s.all, selected: _seriesFilter == null, accent: true, onTap: () => setState(() {
                      _seriesFilter = null;
                      _load();
                    })),
                    for (final x in list) ...[
                      const SizedBox(width: 8),
                      SelectChip(label: x.title, selected: _seriesFilter == x.slug, accent: true, onTap: () => setState(() {
                        _seriesFilter = x.slug;
                        _load();
                      })),
                    ],
                  ],
                ),
              );
            },
          ),
        FutureBuilder<List<ContentCard>>(
          future: _items,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            if (snap.hasError) return ErrorRetry(error: snap.error!, onRetry: () => setState(_load));
            final items = snap.data!;
            if (items.isEmpty) return EmptyState(message: s.emptyHome);
            final today = DateUtils.dateOnly(DateTime.now());
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(children: [
                for (final (i, item) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DatedRow(item: item, highlight: i == 0 && _seriesFilter == null, today: today, p: p),
                  ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

class _DatedRow extends StatelessWidget {
  const _DatedRow({required this.item, required this.highlight, required this.today, required this.p});
  final ContentCard item;
  final bool highlight;
  final DateTime today;
  final Palette p;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final d = item.publishAt;
    final isToday = d != null && DateUtils.dateOnly(d) == today;
    final meta = [item.scriptureReference, if (item.readMinutes != null) s.minutes(item.readMinutes!)]
        .where((x) => x.isNotEmpty)
        .join(' · ');
    return Material(
      color: highlight ? p.surfaceHi : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: highlight ? p.accent : p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openReader(context, item.slug),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SizedBox(
              width: 50,
              child: d == null
                  ? ItemArt(category: item.category, size: 44, radius: 12)
                  : Column(children: [
                      Text(isToday ? s.today : s.monthShort(d),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isToday ? p.accentText : p.muted)),
                      Text('${d.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 16, fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta, style: TextStyle(fontSize: 12, color: p.muted)),
                ],
              ]),
            ),
            if (item.isLocked)
              item.accessLevel == 'premium' ? const PremiumBadge() : Icon(Icons.lock_outline_rounded, size: 18, color: p.muted)
            else if (item.hasAudio)
              Icon(Icons.headphones_rounded, size: 20, color: highlight ? p.accentText : p.muted, semanticLabel: s.audio),
          ]),
        ),
      ),
    );
  }
}
