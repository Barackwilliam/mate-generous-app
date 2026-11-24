import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../audio/audio_controller.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'listen_screen.dart';
import 'plans_screen.dart';

/// The devotional reader. It has its own look (cream paper by default, as in
/// the design; night on request) independent of the rest of the app.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final light = context.select<AppState, bool>((a) => a.readerLight);
    return Theme(
      data: light ? AppTheme.of(Palette.light, Brightness.light) : AppTheme.of(Palette.dark, Brightness.dark),
      child: _Reader(slug: slug),
    );
  }
}

class _Reader extends StatefulWidget {
  const _Reader({required this.slug});
  final String slug;

  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);
  int _maxPercent = 0;
  late final AppState _app;
  ContentDetail? _item;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _scroll.addListener(_track);
    _app.api.revision.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(_Reader old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) {
      _maxPercent = 0;
      _progress.value = 0;
      setState(() {
        _item = null;
        _error = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final item = await _app.api.content(widget.slug);
      if (mounted) {
        setState(() {
          _item = item;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _item == null) setState(() => _error = e);
    }
  }

  void _track() {
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
    final v = (_scroll.offset / _scroll.position.maxScrollExtent).clamp(0.0, 1.0);
    _progress.value = v;
    final pct = (v * 100).round();
    if (pct > _maxPercent) _maxPercent = pct;
  }

  @override
  void dispose() {
    _app.api.revision.removeListener(_load);
    if (_app.isSignedIn) {
      _app.api.reportProgress(widget.slug, percent: _maxPercent == 0 ? 1 : _maxPercent).catchError((_) {});
    }
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _toggle(ContentDetail item, String kind) async {
    if (!_app.isSignedIn) {
      push(context, const AuthScreen());
      return;
    }
    final isBookmark = kind == 'bookmark';
    final value = !(isBookmark ? item.isBookmarked : item.isFavourite);
    setState(() => isBookmark ? item.isBookmarked = value : item.isFavourite = value);
    try {
      await _app.api.setSaved(item.slug, kind, value);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => isBookmark ? item.isBookmarked = !value : item.isFavourite = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(_app.s, e))));
    }
  }

  void _share(ContentDetail item) {
    final s = _app.s;
    final parts = [
      item.title,
      if (item.scriptureReference.isNotEmpty) item.scriptureReference,
      if (item.shareExcerpt.isNotEmpty) item.shareExcerpt,
      '${s.readMoreOn}: ${item.shareUrl}',
    ];
    SharePlus.instance.share(ShareParams(text: parts.join('\n\n')));
  }

  void _settings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.pal.bg,
      showDragHandle: true,
      builder: (_) => const _ReadingSettings(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final item = _item;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(children: [
              RoundButton(icon: const Icon(Icons.arrow_back_rounded), label: s.back, bare: true, onTap: () => Navigator.pop(context)),
              const Spacer(),
              Tooltip(
                message: s.textAndLook,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _settings,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: Text('Aa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text))),
                  ),
                ),
              ),
              const LangToggle(compact: true),
              if (item != null) ...[
                RoundButton(
                  bare: true,
                  icon: Icon(item.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: item.isBookmarked ? p.accentText : p.text),
                  label: s.bookmark,
                  onTap: () => _toggle(item, 'bookmark'),
                ),
                RoundButton(bare: true, icon: const Icon(Icons.ios_share_rounded), label: s.share, onTap: () => _share(item)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (_, v, _) => ThinProgress(value: v, height: 3),
            ),
          ),
          Expanded(
            child: item != null
                ? _Body(item: item, scroll: _scroll, onFavourite: () => _toggle(item, 'favourite'))
                : _error != null
                    ? ErrorRetry(error: _error!, onRetry: () {
                        setState(() => _error = null);
                        _load();
                      })
                    : const Loading(),
          ),
          if (item != null && (item.previous != null || item.next != null))
            Container(
              decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.border))),
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
              child: Row(children: [
                Expanded(child: item.previous == null ? const SizedBox.shrink() : _NavButton(ref: item.previous!, isNext: false)),
                const SizedBox(width: 10),
                Expanded(child: item.next == null ? const SizedBox.shrink() : _NavButton(ref: item.next!, isNext: true)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.item, required this.scroll, required this.onFavourite});
  final ContentDetail item;
  final ScrollController scroll;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final scale = context.select<AppState, double>((a) => a.fontScale);
    final size = 17.0 * scale;
    final gold = '#${p.accentText.toARGB32().toRadixString(16).substring(2)}';
    final rule = '#${p.border.toARGB32().toRadixString(16).substring(2)}';

    Widget html(String data, {double? fontSize}) => HtmlWidget(
          data,
          textStyle: TextStyle(fontFamily: AppTheme.serif, fontSize: fontSize ?? size, height: 1.7, color: p.text),
          customStylesBuilder: (el) => switch (el.localName) {
            'h2' => {'font-family': AppTheme.sans, 'font-size': '1.1em', 'font-weight': '800', 'margin': '22px 0 8px'},
            'h3' => {'font-family': AppTheme.sans, 'font-size': '1.05em', 'font-weight': '700', 'margin': '18px 0 6px'},
            'p' => {'margin': '0 0 14px'},
            'blockquote' => {'margin': '14px 0', 'padding-left': '14px', 'border-left': '3px solid $gold', 'font-style': 'italic'},
            'hr' => {'border-top': '1px solid $rule', 'margin': '18px 0'},
            _ => null,
          },
        );

    final meta = [item.authorName, if (item.readMinutes != null) s.minutes(item.readMinutes!)].whereType<String>().join(' · ');

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(99)),
            child: Text(item.seriesTitle ?? item.category.label(s.en),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.onAccent)),
          ),
        ),
        const SizedBox(height: 12),
        Text(item.title, style: TextStyle(fontSize: 26 * scale.clamp(0.9, 1.25), fontWeight: FontWeight.w800, height: 1.18)),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(meta, style: TextStyle(fontSize: 14, color: p.muted, fontWeight: FontWeight.w600)),
        ],
        if (item.scriptureReference.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
            child: Column(children: [
              if (item.scriptureText.isNotEmpty)
                Text('“${item.scriptureText}”',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, fontSize: size, height: 1.5)),
              const SizedBox(height: 8),
              Text('– ${item.scriptureReference} –',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.accentText)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(aspectRatio: 16 / 7, child: AppImage(url: item.coverImage, fallback: Img.readerBanner)),
        ),
        if (item.hasAudio && !item.isLocked) ...[
          const SizedBox(height: 14),
          PrimaryButton(
            height: 48,
            label: s.listenFor(item.audioLength),
            icon: const Icon(Icons.headphones_rounded),
            onPressed: () {
              context.read<AudioController>().play(item);
              push(context, const ListenScreen());
            },
          ),
        ],
        const SizedBox(height: 18),
        if (item.isLocked)
          _Locked(item: item)
        else ...[
          if (item.body != null) html(item.body!),
          if ((item.application ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.application, style: TextStyle(fontSize: 19 * scale.clamp(0.9, 1.2), fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            html(item.application!),
          ],
          if ((item.prayer ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 4),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(Img.prayerIcon, width: 44, height: 44)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.prayer, style: TextStyle(fontSize: 18 * scale.clamp(0.9, 1.2), fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    html(item.prayer!, fontSize: size - 1),
                  ]),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: onFavourite,
              style: TextButton.styleFrom(foregroundColor: item.isFavourite ? const Color(0xFFE0457B) : p.muted, minimumSize: const Size(44, 44)),
              icon: Icon(item.isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              label: Text(s.favourite, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.item});
  final ContentDetail item;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final signedIn = context.select<AppState, bool>((a) => a.isSignedIn);
    final scale = context.select<AppState, double>((a) => a.fontScale);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if ((item.preview ?? '').isNotEmpty)
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.transparent],
            stops: [0.5, 1],
          ).createShader(r),
          child: Text(item.preview!, style: TextStyle(fontFamily: AppTheme.serif, fontSize: 17 * scale, height: 1.7)),
        ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A1466), Color(0xFF0B1033)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Palette.gold.withValues(alpha: 0.7)),
        ),
        child: Column(children: [
          Image.asset(Img.premium, height: 70),
          const SizedBox(height: 10),
          Text(item.accessLevel == 'premium' ? s.premiumOnly : s.membersOnly,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Text(s.joinToRead, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD5DAF5), height: 1.5)),
          const SizedBox(height: 16),
          PrimaryButton(
            label: signedIn ? s.joinNowArrow : s.signInOrUp,
            trailing: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => push(context, signedIn ? const PlansScreen() : const AuthScreen()),
          ),
        ]),
      ),
    ]);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.ref, required this.isNext});
  final Ref ref;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Material(
      color: isNext ? null : p.surface,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(gradient: isNext ? Palette.goldGradient : null, borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReaderScreen(slug: ref.slug))),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              if (!isNext) Icon(Icons.chevron_left_rounded, color: p.text),
              Expanded(
                child: Column(
                  crossAxisAlignment: isNext ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isNext ? s.next : s.previous,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: (isNext ? p.onAccent : p.text).withValues(alpha: 0.75))),
                    Text(ref.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isNext ? p.onAccent : p.text)),
                  ],
                ),
              ),
              if (isNext) Icon(Icons.chevron_right_rounded, color: p.onAccent),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Text size, the reader's look, and language, from the Aa button.
class _ReadingSettings extends StatelessWidget {
  const _ReadingSettings();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.textSize, style: const TextStyle(fontWeight: FontWeight.w800)),
        Row(children: [
          const Text('A', style: TextStyle(fontFamily: AppTheme.serif, fontSize: 14)),
          Expanded(child: Slider(min: AppState.minFont, max: AppState.maxFont, divisions: 7, value: app.fontScale, onChanged: app.setFontScale)),
          const Text('A', style: TextStyle(fontFamily: AppTheme.serif, fontSize: 26)),
        ]),
        const SizedBox(height: 8),
        Text(s.readerLook, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Segmented(
          options: {true: s.light, false: s.dark},
          value: app.readerLight,
          onChanged: app.setReaderLight,
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text(s.language, style: const TextStyle(fontWeight: FontWeight.w800))),
          const LangToggle(),
        ]),
        const SizedBox(height: 4),
        Text(s.en ? 'Messages stay in the language they were written in.' : 'Jumbe zinabaki katika lugha zilizoandikwa.',
            style: TextStyle(fontSize: 12, color: p.muted)),
      ]),
    );
  }
}

/// A row of options with the chosen one in gold.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
      child: Row(children: [
        for (final e in options.entries)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == e.key,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: value == e.key ? Palette.goldGradient : null, borderRadius: BorderRadius.circular(10)),
                  child: Text(e.value,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: value == e.key ? p.onAccent : p.muted)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key, required this.value, required this.onChanged});
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Segmented<ThemeMode>(
      options: {ThemeMode.dark: s.dark, ThemeMode.light: s.light, ThemeMode.system: s.system},
      value: value,
      onChanged: onChanged,
    );
  }
}
