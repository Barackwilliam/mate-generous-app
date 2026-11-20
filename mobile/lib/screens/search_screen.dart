import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

/// Search by title, Scripture, keyword, series, topic or author.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.topic});
  final Topic? topic;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.topic?.name ?? '');
  Timer? _debounce;
  Future<List<ContentCard>>? _results;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.topic != null) _run();
  }

  void _run() {
    final q = _controller.text.trim();
    final api = context.read<AppState>().api;
    final topic = widget.topic != null && q == widget.topic!.name ? widget.topic!.slug : null;
    if (q.length < 2 && topic == null) {
      setState(() => _results = null);
      return;
    }
    setState(() => _results = api.contents(
          query: topic == null ? q : null,
          topic: topic,
          kind: switch (_filter) { 'devotional' || 'sermon' || 'article' => _filter, _ => null },
          audioOnly: _filter == 'audio',
        ));
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _run);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final filters = {'all': s.all, 'devotional': s.devotionals, 'audio': s.audio, 'sermon': s.sermons, 'article': s.articles};
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: widget.topic == null,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _run(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: s.searchHint,
                    prefixIcon: Icon(Icons.search_rounded, color: p.accentText),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: p.accentText, minimumSize: const Size(44, 48)),
                child: Text(s.cancel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              children: [
                for (final e in filters.entries) ...[
                  SelectChip(label: e.value, selected: _filter == e.key, onTap: () {
                    _filter = e.key;
                    _run();
                  }),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: _results == null
                ? EmptyState(message: s.searchStart, icon: Icon(Icons.search_rounded, size: 40, color: p.faint))
                : FutureBuilder<List<ContentCard>>(
                    future: _results,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) return const Loading();
                      if (snap.hasError) return ErrorRetry(error: snap.error!, onRetry: _run);
                      final items = snap.data!;
                      if (items.isEmpty) return EmptyState(message: s.noResults, icon: Icon(Icons.search_off_rounded, size: 40, color: p.faint));
                      final best = items.first;
                      return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                        _BestResult(item: best),
                        for (final item in items.skip(1)) ContentRow(item: item),
                      ]);
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _BestResult extends StatelessWidget {
  const _BestResult({required this.item});
  final ContentCard item;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = context.s;
    final accent = parseHex(item.category.accentHex, Palette.gold);
    final fg = p.onTint(accent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Material(
        color: p.tint(accent),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => openReader(context, item.slug),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.category.label(s.en).toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: fg.withValues(alpha: 0.85))),
              const SizedBox(height: 6),
              Text(item.title, style: TextStyle(fontFamily: AppTheme.serif, fontSize: 19, fontWeight: FontWeight.w600, color: fg)),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.5, color: fg.withValues(alpha: 0.9))),
              ],
              if (item.scriptureReference.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.scriptureReference, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
