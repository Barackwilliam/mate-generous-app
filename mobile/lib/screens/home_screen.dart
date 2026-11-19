import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.home();
  }

  Future<void> _reload() async {
    final next = context.read<AppState>().api.home();
    setState(() => _future = next);
    await next.catchError((_) => HomeData(sections: []));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mate Generous')),
      body: FutureBuilder<HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return ErrorRetry(message: snap.error.toString(), onRetry: _reload);
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (data.tonight != null) TonightCard(item: data.tonight!),
                for (final s in data.sections) _Section(section: s),
                if (data.tonight == null && data.sections.isEmpty)
                  const EmptyState(icon: Icons.nights_stay, message: 'Jumbe zitaonekana hapa hivi karibuni.'),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tonight's Message: cover, title, verse and READ / LISTEN.
class TonightCard extends StatelessWidget {
  const TonightCard({super.key, required this.item});
  final ContentDetail item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: AppTheme.night,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              CoverImage(url: item.coverImage, height: 180, icon: Icons.nights_stay),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(20)),
                  child: const Text('UJUMBE WA USIKU HUU',
                      style: TextStyle(color: AppTheme.night, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.8)),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                if (item.scriptureReference.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.scriptureText.isNotEmpty ? '“${item.scriptureText}” — ${item.scriptureReference}' : item.scriptureReference,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: Colors.white70, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.night),
                    onPressed: () => openReader(context, item.slug),
                    icon: const Icon(Icons.menu_book),
                    label: const Text('SOMA'),
                  ),
                  if (item.hasAudio) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                      onPressed: () => openReader(context, item.slug),
                      icon: const Icon(Icons.headphones),
                      label: const Text('SIKILIZA'),
                    ),
                  ],
                ]),
              ]),
            ),
          ]),
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
    final isSeries = section.kind == 'series_list';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
        child: Row(children: [
          Expanded(child: Text(section.title, style: Theme.of(context).textTheme.titleMedium)),
          if (section.categorySlug != null)
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoryScreen(slug: section.categorySlug!, name: section.title))),
              child: const Text('Zote'),
            ),
        ]),
      ),
      SizedBox(
        height: isSeries ? 150 : 190,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: isSeries ? section.series.length : section.items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, i) =>
              isSeries ? _SeriesTile(series: section.series[i]) : ContentCardTile(item: section.items[i]),
        ),
      ),
    ]);
  }
}

class _SeriesTile extends StatelessWidget {
  const _SeriesTile({required this.series});
  final SeriesInfo series;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        child: Card(
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CategoryScreen(seriesSlug: series.slug, name: series.title))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CoverImage(url: series.coverImage, height: 80, icon: Icons.collections_bookmark),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(series.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ]),
          ),
        ),
      );
}
