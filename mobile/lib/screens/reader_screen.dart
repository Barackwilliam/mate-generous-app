import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_screen.dart';

/// The devotional reader: Scripture, text, application, prayer, next/previous,
/// bookmark/favourite, font size, dark mode and sharing of the approved excerpt.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.slug});
  final String slug;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<ContentDetail> _future;
  final _scroll = ScrollController();
  int _maxPercent = 0;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _future = _app.api.content(widget.slug);
    _scroll.addListener(_trackProgress);
  }

  void _trackProgress() {
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
    final p = (_scroll.offset / _scroll.position.maxScrollExtent * 100).clamp(0, 100).round();
    if (p > _maxPercent) _maxPercent = p;
  }

  @override
  void dispose() {
    if (_app.isSignedIn && _maxPercent > 0) {
      _app.api.reportProgress(widget.slug, _maxPercent).catchError((_) {});
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggle(ContentDetail item, String kind) async {
    if (!_app.isSignedIn) {
      _askToSignIn();
      return;
    }
    final isBookmark = kind == 'bookmark';
    final newValue = !(isBookmark ? item.isBookmarked : item.isFavourite);
    setState(() => isBookmark ? item.isBookmarked = newValue : item.isFavourite = newValue);
    try {
      await _app.api.setSaved(item.slug, kind, newValue);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => isBookmark ? item.isBookmarked = !newValue : item.isFavourite = !newValue);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _askToSignIn() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _share(ContentDetail item) {
    final parts = [
      item.title,
      if (item.scriptureReference.isNotEmpty) item.scriptureReference,
      if (item.shareExcerpt.isNotEmpty) item.shareExcerpt,
      'Soma zaidi kwenye Mate Generous: ${item.shareUrl}',
    ];
    SharePlus.instance.share(ShareParams(text: parts.join('\n\n')));
  }

  void _readingSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer<AppState>(
        builder: (context, app, _) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ukubwa wa maandishi', style: Theme.of(context).textTheme.titleSmall),
            Row(children: [
              const Text('A', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Slider(
                  min: AppState.minFont,
                  max: AppState.maxFont,
                  divisions: 7,
                  value: app.fontScale,
                  onChanged: app.setFontScale,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 24)),
            ]),
            const SizedBox(height: 8),
            Text('Mwonekano', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Mchana')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Usiku')),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android), label: Text('Simu')),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setThemeMode(s.first),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentDetail>(
      future: _future,
      builder: (context, snap) {
        final item = snap.data;
        return Scaffold(
          appBar: AppBar(
            actions: item == null
                ? null
                : [
                    IconButton(
                      tooltip: 'Alamisho',
                      icon: Icon(item.isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                      onPressed: () => _toggle(item, 'bookmark'),
                    ),
                    IconButton(
                      tooltip: 'Pendwa',
                      icon: Icon(item.isFavourite ? Icons.favorite : Icons.favorite_border),
                      onPressed: () => _toggle(item, 'favourite'),
                    ),
                    IconButton(tooltip: 'Shiriki', icon: const Icon(Icons.share), onPressed: () => _share(item)),
                    IconButton(tooltip: 'Maandishi', icon: const Icon(Icons.text_fields), onPressed: _readingSettings),
                  ],
          ),
          body: switch (snap.connectionState) {
            ConnectionState.done when snap.hasError => ErrorRetry(
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = _app.api.content(widget.slug)),
              ),
            ConnectionState.done => _ReaderBody(item: item!, scroll: _scroll, onSignIn: _askToSignIn),
            _ => const Center(child: CircularProgressIndicator()),
          },
          bottomNavigationBar: item == null ? null : _PrevNextBar(item: item),
        );
      },
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({required this.item, required this.scroll, required this.onSignIn});
  final ContentDetail item;
  final ScrollController scroll;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppState>().fontScale;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final bodySize = 17.0 * scale;

    final gold = '#${AppTheme.gold.toARGB32().toRadixString(16).substring(2)}';
    Widget html(String data) => HtmlWidget(
          data,
          textStyle: TextStyle(fontSize: bodySize, height: 1.6),
          customStylesBuilder: (element) => switch (element.localName) {
            'h2' => {'font-size': '1.3em', 'margin': '18px 0 8px'},
            'h3' => {'font-size': '1.15em', 'margin': '16px 0 6px'},
            'p' => {'margin': '0 0 12px'},
            'blockquote' => {
                'margin': '12px 0',
                'padding-left': '14px',
                'border-left': '3px solid $gold',
                'font-style': 'italic',
              },
            _ => null,
          },
        );

    Widget section(String title, IconData icon, String? body) {
      if (body == null || body.trim().isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: text.titleMedium)]),
          const SizedBox(height: 8),
          html(body),
        ]),
      );
    }

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        if (item.coverImage != null && item.coverImage!.isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(16), child: CoverImage(url: item.coverImage, height: 190)),
        const SizedBox(height: 16),
        Text(item.seriesTitle ?? item.categoryName, style: text.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text(item.title, style: text.headlineMedium?.copyWith(fontSize: 28 * scale)),
        if (item.authorName != null) ...[
          const SizedBox(height: 6),
          Text(item.authorName!, style: text.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        ],
        if (item.scriptureReference.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppTheme.gold, width: 4)),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (item.scriptureText.isNotEmpty)
                Text('“${item.scriptureText}”',
                    style: TextStyle(fontSize: bodySize, fontStyle: FontStyle.italic, height: 1.5)),
              const SizedBox(height: 6),
              Text(item.scriptureReference, style: text.titleSmall),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        if (item.isLocked)
          _LockedNotice(item: item, onSignIn: onSignIn)
        else ...[
          if (item.body != null) html(item.body!),
          section('Matumizi ya vitendo', Icons.directions_walk, item.application),
          section('Sala', Icons.volunteer_activism, item.prayer),
        ],
      ],
    );
  }
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.item, required this.onSignIn});
  final ContentDetail item;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AppState>().isSignedIn;
    final premium = item.accessLevel == 'premium';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((item.preview ?? '').isNotEmpty)
        Text(item.preview!, style: const TextStyle(fontSize: 17, height: 1.6)),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.lock_outline, size: 36),
            const SizedBox(height: 8),
            Text(premium ? 'Ujumbe huu ni kwa wanachama wa Premium.' : 'Ujumbe huu ni kwa wanachama.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('Jiunge ili kusoma ujumbe kamili, sala na kusikiliza sauti.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (!signedIn)
              FilledButton(onPressed: onSignIn, child: const Text('Ingia au jisajili'))
            else
              FilledButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Malipo yatafunguliwa hivi karibuni.'))),
                child: const Text('Jiunge sasa'),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _PrevNextBar extends StatelessWidget {
  const _PrevNextBar({required this.item});
  final ContentDetail item;

  void _go(BuildContext context, Ref ref) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReaderScreen(slug: ref.slug)));
  }

  @override
  Widget build(BuildContext context) {
    if (item.previous == null && item.next == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Expanded(
            child: item.previous == null
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: () => _go(context, item.previous!),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(item.previous!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
          ),
          Expanded(
            child: item.next == null
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _go(context, item.next!),
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Flexible(child: Text(item.next!.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
