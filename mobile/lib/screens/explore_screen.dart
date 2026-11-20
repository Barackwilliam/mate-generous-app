import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'category_screen.dart';
import 'search_screen.dart';

/// Every department the admin has published, in the admin's order.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<(List<Category>, List<Topic>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Category>, List<Topic>)> _load() async {
    final api = context.read<AppState>().api;
    final r = await Future.wait([api.categories(), api.topics().catchError((_) => <Topic>[])]);
    return (r[0] as List<Category>, r[1] as List<Topic>);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(List<Category>, List<Topic>)>(
          future: _future,
          builder: (context, snap) {
            return ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
              Row(children: [
                Expanded(child: Text(s.discover, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
                const LangToggle(),
              ]),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: s.search,
                child: Material(
                  color: p.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => push(context, const SearchScreen()),
                    child: SizedBox(
                      height: 50,
                      child: Row(children: [
                        const SizedBox(width: 16),
                        Icon(Icons.search_rounded, color: p.muted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.searchHint, style: TextStyle(color: p.faint, fontSize: 15), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ),
                ),
              ),
              if (snap.connectionState != ConnectionState.done)
                const Loading()
              else if (snap.hasError)
                ErrorRetry(error: snap.error!, onRetry: () => setState(() => _future = _load()))
              else ...[
                if (snap.data!.$2.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in snap.data!.$2.take(6))
                      SelectChip(label: t.name, selected: false, onTap: () => push(context, SearchScreen(topic: t))),
                  ]),
                ],
                const SizedBox(height: 18),
                ..._grid(context, snap.data!.$1),
              ],
            ]);
          },
        ),
      ),
    );
  }

  List<Widget> _grid(BuildContext context, List<Category> cats) {
    final s = context.s;
    final p = context.pal;
    final flagship = cats.where((c) => c.isFlagship).toList();
    final rest = cats.where((c) => !c.isFlagship).toList();
    return [
      for (final c in flagship)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: p.accent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => push(context, CategoryScreen.forCategory(c)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Palette.night, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: const CrossIcon(size: 26, color: Palette.gold),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.label(s.en),
                          style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 20, fontWeight: FontWeight.w600, color: Palette.night)),
                      if (c.about(s.en).isNotEmpty)
                        Text(c.about(s.en), maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A3608))),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Palette.night),
                ]),
              ),
            ),
          ),
        ),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          for (final c in rest)
            ColourTile(
              title: c.label(s.en),
              subtitle: c.about(s.en),
              category: c,
              height: double.infinity,
              badge: c.slug == 'sermons' ? const PremiumBadge() : null,
              onTap: () => push(context, CategoryScreen.forCategory(c)),
            ),
        ],
      ),
    ];
  }
}
