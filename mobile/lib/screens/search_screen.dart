import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../audio/audio_controller.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';
import 'listen_screen.dart';

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
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _query = _controller.text.trim();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = text.trim()));
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
    final api = context.read<AppState>().api;
    final filters = {'all': s.all, 'devotional': s.devotionals, 'audio': s.audio, 'sermon': s.sermons, 'article': s.articles};
    final topic = widget.topic != null && _query == widget.topic!.name ? widget.topic!.slug : null;
    final active = _query.length >= 2 || topic != null;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
              child: Row(children: [
                RoundButton(icon: const Icon(Icons.arrow_back_rounded), label: s.back, bare: true, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: widget.topic == null,
                    onChanged: _onChanged,
                    onSubmitted: (t) => setState(() => _query = t.trim()),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: s.searchContent,
                      prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: s.cancel,
                              icon: Icon(Icons.close_rounded, color: p.text),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: p.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: p.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: p.accent, width: 1.5)),
                    ),
                  ),
                ),
              ]),
            ),
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                children: [
                  for (final e in filters.entries) ...[
                    SelectChip(label: e.value, selected: _filter == e.key, onTap: () => setState(() => _filter = e.key)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: !active
                  ? SingleChildScrollView(child: EmptyState(title: s.search, message: s.searchStart, icon: const Icon(Icons.search_rounded)))
                  : LiveData<List<ContentCard>>(
                      watchKey: '$_query|$_filter|$topic',
                      load: () => api.contents(
                        query: topic == null ? _query : null,
                        topic: topic,
                        kind: switch (_filter) { 'devotional' || 'sermon' || 'article' => _filter, _ => null },
                        audioOnly: _filter == 'audio',
                      ),
                      builder: (context, items, _) {
                        if (items.isEmpty) {
                          return SingleChildScrollView(child: EmptyState(title: s.noResults, message: s.searchStart, icon: const Icon(Icons.search_off_rounded)));
                        }
                        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                          _BestResult(item: items.first),
                          if (items.length > 1) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                              child: Text(s.otherResults, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            ),
                            for (final item in items.skip(1)) ContentRow(item: item),
                          ],
                        ]);
                      },
                    ),
            ),
          ]),
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Material(
        color: p.surfaceHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.border, width: 1.2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openReader(context, item.slug),
          child: Row(children: [
            ItemArt(category: item.category, imageUrl: item.coverImage, size: 96, width: 104, radius: 0),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 4),
                Text(item.scriptureReference.isNotEmpty ? item.scriptureReference : item.category.label(s.en),
                    style: TextStyle(fontSize: 13, color: p.muted)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                button: true,
                label: item.hasAudio && !item.isLocked ? s.play : s.read(null),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    if (item.hasAudio && !item.isLocked) {
                      await context.read<AudioController>().playSlug(item.slug);
                      if (context.mounted) push(context, const ListenScreen());
                    } else {
                      openReader(context, item.slug);
                    }
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(gradient: Palette.goldGradient, shape: BoxShape.circle),
                    child: Icon(item.hasAudio && !item.isLocked ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded, color: p.onAccent, size: 28),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
