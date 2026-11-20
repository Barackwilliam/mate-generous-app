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

/// The devotional reader: Scripture, text with headings, quotes and images,
/// practical application, prayer, next/previous, save, favourite, sharing of
/// the approved excerpt, text size, dark mode and language.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.slug});
  final String slug;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<ContentDetail> _future;
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);
  int _maxPercent = 0;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _future = _app.api.content(widget.slug);
    _scroll.addListener(_track);
  }

  @override
  void didUpdateWidget(ReaderScreen old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) {
      _maxPercent = 0;
      _progress.value = 0;
      _future = _app.api.content(widget.slug);
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
    return FutureBuilder<ContentDetail>(
      future: _future,
      builder: (context, snap) {
        final item = snap.data;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(children: [
                  RoundButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), label: s.back, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  if (item != null) ...[
                    _ChipButton(label: 'Aa', tooltip: s.textAndLook, onTap: _settings),
                    const SizedBox(width: 8),
                    RoundButton(
                      icon: Icon(item.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                      label: s.bookmark,
                      filled: item.isBookmarked,
                      onTap: () => _toggle(item, 'bookmark'),
                    ),
                    const SizedBox(width: 8),
                    RoundButton(
                      icon: Icon(item.isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                      label: s.favourite,
                      filled: item.isFavourite,
                      onTap: () => _toggle(item, 'favourite'),
                    ),
                    const SizedBox(width: 8),
                    RoundButton(icon: const Icon(Icons.ios_share_rounded), label: s.share, onTap: () => _share(item)),
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
                child: switch (snap.connectionState) {
                  ConnectionState.done when snap.hasError => ErrorRetry(
                      error: snap.error!,
                      onRetry: () => setState(() => _future = _app.api.content(widget.slug)),
                    ),
                  ConnectionState.done => _Body(item: item!, scroll: _scroll),
                  _ => const Loading(),
                },
              ),
              if (item != null && (item.previous != null || item.next != null))
                Container(
                  decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.border))),
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
                  child: Row(children: [
                    Expanded(child: item.previous == null ? const SizedBox.shrink() : _NavButton(ref: item.previous!, isNext: false)),
                    const SizedBox(width: 10),
                    Expanded(child: item.next == null ? const SizedBox.shrink() : _NavButton(ref: item.next!, isNext: true)),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.tooltip, required this.onTap});
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface,
        shape: StadiumBorder(side: BorderSide(color: p.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontFamily: AppTheme.serif, fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.item, required this.scroll});
  final ContentDetail item;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final scale = context.select<AppState, double>((a) => a.fontScale);
    final size = 17.0 * scale;
    final gold = '#${p.accentText.toARGB32().toRadixString(16).substring(2)}';
    final rule = '#${p.border.toARGB32().toRadixString(16).substring(2)}';

    Widget html(String data) => HtmlWidget(
          data,
          textStyle: TextStyle(fontFamily: AppTheme.serif, fontSize: size, height: 1.7, color: p.text),
          customStylesBuilder: (el) => switch (el.localName) {
            'h2' => {'font-size': '1.2em', 'font-weight': '600', 'margin': '22px 0 8px'},
            'h3' => {'font-size': '1.1em', 'font-weight': '600', 'margin': '18px 0 6px'},
            'p' => {'margin': '0 0 14px'},
            'blockquote' => {'margin': '14px 0', 'padding-left': '14px', 'border-left': '3px solid $gold', 'font-style': 'italic'},
            'hr' => {'border-top': '1px solid $rule', 'margin': '18px 0'},
            _ => null,
          },
        );

    Widget block(String title, Widget icon, String? body) {
      if (body == null || body.trim().isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconTheme(data: IconThemeData(color: p.accentText, size: 18), child: icon),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, color: p.accentText)),
            ),
          ]),
          const SizedBox(height: 10),
          html(body),
        ]),
      );
    }

    final meta = [item.authorName, if (item.readMinutes != null) s.minRead(item.readMinutes!)].whereType<String>().join(' · ');

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
      children: [
        if (item.coverImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(item.coverImage!, height: 190, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
          const SizedBox(height: 18),
        ],
        Text((item.seriesTitle ?? item.category.label(s.en)).toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: p.accentText)),
        const SizedBox(height: 8),
        Text(item.title, style: TextStyle(fontFamily: AppTheme.serif, fontSize: 30 * scale.clamp(0.9, 1.25), fontWeight: FontWeight.w600, height: 1.15)),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: p.text, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: CrossIcon(size: 15, color: p.accent),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(meta, style: TextStyle(fontSize: 13, color: p.muted))),
          ]),
        ],
        if (item.scriptureReference.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (item.scriptureText.isNotEmpty)
                Text('“${item.scriptureText}”',
                    style: TextStyle(fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, fontSize: size + 1, height: 1.5)),
              const SizedBox(height: 8),
              Text(item.scriptureReference, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.accentText)),
            ]),
          ),
        ],
        if (item.hasAudio && !item.isLocked) ...[
          const SizedBox(height: 16),
          SecondaryButton(
            label: s.listenFor(item.audioLength),
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: () {
              context.read<AudioController>().play(item);
              push(context, const ListenScreen());
            },
          ),
        ],
        const SizedBox(height: 22),
        if (item.isLocked)
          _Locked(item: item)
        else ...[
          if (item.body != null) html(item.body!),
          _CrossRule(color: p.accentText, line: p.border),
          block(s.application, const Icon(Icons.directions_walk_rounded), item.application),
          block(s.prayer, const Icon(Icons.volunteer_activism_outlined), item.prayer),
        ],
      ],
    );
  }
}

class _CrossRule extends StatelessWidget {
  const _CrossRule({required this.color, required this.line});
  final Color color;
  final Color line;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Divider(color: line)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: CrossIcon(size: 14, color: color)),
            Expanded(child: Divider(color: line)),
          ]),
        ),
      );
}

class _Locked extends StatelessWidget {
  const _Locked({required this.item});
  final ContentDetail item;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final signedIn = context.select<AppState, bool>((a) => a.isSignedIn);
    final scale = context.select<AppState, double>((a) => a.fontScale);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        decoration: BoxDecoration(color: p.surfaceHi, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.accent)),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Icon(Icons.lock_rounded, color: p.onAccent),
          ),
          const SizedBox(height: 12),
          Text(item.accessLevel == 'premium' ? s.premiumOnly : s.membersOnly,
              textAlign: TextAlign.center, style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(s.joinToRead, textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: signedIn ? s.joinNow : s.signInOrUp,
              onPressed: () => push(context, signedIn ? const PlansScreen() : const AuthScreen()),
            ),
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
    final bg = isNext ? p.text : p.surface;
    final fg = isNext ? p.bg : p.text;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReaderScreen(slug: ref.slug))),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            if (!isNext) Icon(Icons.chevron_left_rounded, color: fg),
            Expanded(
              child: Column(
                crossAxisAlignment: isNext ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isNext ? s.next : s.previous, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg.withValues(alpha: 0.7))),
                  Text(ref.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                ],
              ),
            ),
            if (isNext) Icon(Icons.chevron_right_rounded, color: fg),
          ]),
        ),
      ),
    );
  }
}

/// Text size, appearance and language, from the Aa button.
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
        Text(s.textSize, style: const TextStyle(fontWeight: FontWeight.w700)),
        Row(children: [
          const Text('A', style: TextStyle(fontFamily: AppTheme.serif, fontSize: 14)),
          Expanded(
            child: Slider(min: AppState.minFont, max: AppState.maxFont, divisions: 7, value: app.fontScale, onChanged: app.setFontScale),
          ),
          const Text('A', style: TextStyle(fontFamily: AppTheme.serif, fontSize: 26)),
        ]),
        const SizedBox(height: 8),
        Text(s.appearance, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ThemeSwitch(value: app.themeMode, onChanged: app.setThemeMode),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text(s.language, style: const TextStyle(fontWeight: FontWeight.w700))),
          const LangToggle(),
        ]),
        const SizedBox(height: 4),
        Text(s.en ? 'Messages stay in the language they were written in.' : 'Jumbe zinabaki katika lugha zilizoandikwa.',
            style: TextStyle(fontSize: 12, color: p.muted)),
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
    final p = context.pal;
    final options = {ThemeMode.dark: s.dark, ThemeMode.light: s.light, ThemeMode.system: s.system};
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
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: value == e.key ? p.accent : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Text(e.value,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: value == e.key ? p.onAccent : p.muted)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
