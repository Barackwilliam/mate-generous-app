import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Every category the admin has published, in the admin's order.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.categories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Makundi')),
      body: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ErrorRetry(
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = context.read<AppState>().api.categories()),
            );
          }
          final cats = snap.data!;
          return ListView.separated(
            itemCount: cats.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = cats[i];
              return ListTile(
                leading: CircleAvatar(child: Icon(c.isFlagship ? Icons.nights_stay : Icons.auto_stories)),
                title: Text(c.name),
                subtitle: c.description.isEmpty ? null : Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => CategoryScreen(slug: c.slug, name: c.name))),
              );
            },
          );
        },
      ),
    );
  }
}

/// One category (with its series as chips) or one series.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, this.slug, this.seriesSlug, required this.name});
  final String? slug;
  final String? seriesSlug;
  final String name;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<ContentCard>> _items;
  Future<List<SeriesInfo>>? _series;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<AppState>().api;
    _items = api.contents(category: widget.slug, series: widget.seriesSlug);
    if (widget.slug != null) _series = api.series(category: widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: ListView(children: [
        if (_series != null)
          FutureBuilder<List<SeriesInfo>>(
            future: _series,
            builder: (context, snap) {
              final list = snap.data ?? const [];
              if (list.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (final s in list)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(s.title),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => CategoryScreen(seriesSlug: s.slug, name: s.title))),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        FutureBuilder<List<ContentCard>>(
          future: _items,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) return ErrorRetry(message: snap.error.toString(), onRetry: () => setState(_load));
            if (snap.data!.isEmpty) return const EmptyState(icon: Icons.inbox, message: 'Bado hakuna jumbe hapa.');
            return Column(children: [for (final item in snap.data!) ContentTile(item: item)]);
          },
        ),
      ]),
    );
  }
}
