import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';

/// One department (with its series as filter chips) or one series.
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
  String? _seriesFilter;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final api = context.read<AppState>().api;
    final cat = widget.category;
    final look = cat == null ? DeptLook.fallback : DeptLook.of(cat);
    final title = cat != null && widget.seriesSlug == null ? cat.label(s.en) : widget.title;
    final about = widget.subtitle ?? (cat is Category ? cat.about(s.en) : '');
    final cover = cat is Category ? cat.coverImage : null;

    return Scaffold(
      body: NightBackground(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          SizedBox(
            height: 290,
            child: Stack(fit: StackFit.expand, children: [
              AppImage(url: cover, fallback: look.picture),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x330B1033), Color(0x000B1033), Color(0xF20B1033)],
                    stops: [0.0, 0.4, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Row(children: [
                      RoundButton(icon: const Icon(Icons.arrow_back_rounded), label: s.back, onImage: true, onTap: () => Navigator.pop(context)),
                      const Spacer(),
                      const LangToggle(onImage: true),
                    ]),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(look.iconPath, width: 56, height: 56)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 30, fontWeight: FontWeight.w600, color: Colors.white, height: 1.1)),
                      if (about.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(about, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFFD5DAF5))),
                      ],
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          if (widget.slug != null)
            LiveData<List<SeriesInfo>>(
              load: () => api.series(category: widget.slug),
              loading: const SizedBox(height: 8),
              builder: (context, list, _) {
                if (list.isEmpty) return const SizedBox(height: 8);
                return SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    children: [
                      SelectChip(label: s.all, selected: _seriesFilter == null, onTap: () => setState(() => _seriesFilter = null)),
                      for (final x in list) ...[
                        const SizedBox(width: 8),
                        SelectChip(label: x.title, selected: _seriesFilter == x.slug, onTap: () => setState(() => _seriesFilter = x.slug)),
                      ],
                    ],
                  ),
                );
              },
            ),
          LiveData<List<ContentCard>>(
            watchKey: _seriesFilter,
            load: () => api.contents(
              category: _seriesFilter == null ? widget.slug : null,
              series: _seriesFilter ?? widget.seriesSlug,
            ),
            builder: (context, items, _) {
              if (items.isEmpty) return EmptyState(message: s.emptyHome);
              final today = DateUtils.dateOnly(DateTime.now());
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(children: [
                  for (final (i, item) in items.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DatedRow(item: item, highlight: i == 0 && _seriesFilter == null && widget.seriesSlug == null, today: today, p: p),
                    ),
                ]),
              );
            },
          ),
        ]),
      ),
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
    final meta = [item.scriptureReference, if (item.readMinutes != null) s.minutes(item.readMinutes!)].where((x) => x.isNotEmpty).join(' · ');
    return Material(
      color: highlight ? p.surfaceHi : p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: highlight ? p.accent : p.border)),
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
                      Text('${d.day}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                    ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 16.5, fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta, style: TextStyle(fontSize: 12.5, color: p.muted)),
                ],
              ]),
            ),
            if (item.isLocked)
              item.accessLevel == 'premium' ? const PremiumBadge() : Icon(Icons.lock_rounded, size: 18, color: p.muted)
            else if (item.hasAudio)
              Icon(Icons.headphones_rounded, size: 20, color: highlight ? p.accentText : p.muted, semanticLabel: s.audio)
            else
              Icon(Icons.chevron_right_rounded, color: p.muted),
          ]),
        ),
      ),
    );
  }
}
