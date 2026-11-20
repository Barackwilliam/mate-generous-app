import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../audio/audio_controller.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// The full-screen player.
class ListenScreen extends StatelessWidget {
  const ListenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final audio = context.watch<AudioController>();
    final item = audio.current;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(children: [
            Row(children: [
              RoundButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24), label: s.close, onTap: () => Navigator.pop(context)),
              Expanded(
                child: Column(children: [
                  Text(s.nowPlayingFrom, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: p.muted)),
                  Text(item?.category.label(s.en) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
              const LangToggle(),
            ]),
            const SizedBox(height: 22),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = c.maxHeight.clamp(0.0, c.maxWidth);
                  return Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: item?.coverImage != null
                            ? Image.network(item!.coverImage!, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => DawnCrossArt(height: side, crossLight: true, crossX: 0.5))
                            : DawnCrossArt(height: side, crossLight: true, crossX: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            if (item == null)
              EmptyState(message: s.noAudio)
            else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 24, fontWeight: FontWeight.w600, height: 1.2)),
                    const SizedBox(height: 4),
                    Text([item.authorName, item.scriptureReference].whereType<String>().where((x) => x.isNotEmpty).join(' · '),
                        style: TextStyle(fontSize: 14, color: p.muted)),
                  ]),
                ),
                IconButton(
                  tooltip: s.read(null),
                  onPressed: () => openReader(context, item.slug),
                  icon: Icon(Icons.menu_book_rounded, color: p.accentText),
                ),
              ]),
              if (audio.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(s.audioFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 14),
              _Progress(audio: audio),
              const SizedBox(height: 10),
              _Controls(audio: audio, item: item),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.audio});
  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final player = audio.player;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final total = player.duration ?? Duration(seconds: audio.current?.audioSeconds ?? 0);
        final max = total.inMilliseconds <= 0 ? 1.0 : total.inMilliseconds.toDouble();
        return Column(children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 6, overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              value: pos.inMilliseconds.clamp(0, max).toDouble(),
              max: max,
              onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_fmt(pos), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.muted)),
            Text('-${_fmt(total - pos < Duration.zero ? Duration.zero : total - pos)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.muted)),
          ]),
        ]);
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.audio, required this.item});
  final AudioController audio;
  final ContentDetail item;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Semantics(
        button: true,
        label: s.speed,
        child: OutlinedButton(
          onPressed: audio.cycleSpeed,
          style: OutlinedButton.styleFrom(
            foregroundColor: p.text,
            side: BorderSide(color: p.border),
            minimumSize: const Size(56, 40),
            shape: const StadiumBorder(),
          ),
          child: Text('${audio.speed.toString().replaceAll(RegExp(r'\.0$'), '')}×', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      IconButton(
        tooltip: item.previous == null ? s.rewind15 : s.prevEpisode,
        iconSize: 30,
        onPressed: () => audio.skip(-15),
        icon: Icon(Icons.replay_rounded, color: p.text),
      ),
      StreamBuilder<PlayerState>(
        stream: audio.player.playerStateStream,
        builder: (context, snap) {
          final state = snap.data;
          final busy = audio.loading ||
              state?.processingState == ProcessingState.loading ||
              state?.processingState == ProcessingState.buffering;
          final playing = state?.playing ?? false;
          return Semantics(
            button: true,
            label: playing ? s.pause : s.play,
            child: Material(
              color: p.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: audio.toggle,
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: Center(
                    child: busy
                        ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: p.onAccent))
                        : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: p.onAccent),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      IconButton(
        tooltip: s.forward15,
        iconSize: 30,
        onPressed: () => audio.skip(15),
        icon: Transform.flip(flipX: true, child: Icon(Icons.replay_rounded, color: p.text)),
      ),
      IconButton(
        tooltip: s.nextEpisode,
        iconSize: 28,
        onPressed: item.next == null ? null : () => audio.playSlug(item.next!.slug),
        icon: Icon(Icons.skip_next_rounded, color: item.next == null ? p.border : p.text),
      ),
    ]);
  }
}

/// The Listen tab: what is playing, and every message with audio.
class ListenTab extends StatefulWidget {
  const ListenTab({super.key});

  @override
  State<ListenTab> createState() => _ListenTabState();
}

class _ListenTabState extends State<ListenTab> {
  late Future<List<ContentCard>> _future = context.read<AppState>().api.contents(audioOnly: true);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final audio = context.watch<AudioController>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: p.accent,
          onRefresh: () async {
            final next = context.read<AppState>().api.contents(audioOnly: true);
            setState(() => _future = next);
            await next.catchError((_) => <ContentCard>[]);
          },
          child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(children: [
                Expanded(child: Text(s.listen, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
                const LangToggle(),
              ]),
            ),
            if (audio.current != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Material(
                  color: p.surfaceHi,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: p.accent)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => push(context, const ListenScreen()),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(14), child: const SizedBox(width: 56, height: 56, child: DawnCrossArt(height: 56, crossLight: true, crossX: 0.5))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.nowPlayingFrom, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: p.accentText)),
                            Text(audio.current!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        IconButton(
                          tooltip: audio.playing ? s.pause : s.play,
                          onPressed: audio.toggle,
                          icon: Icon(audio.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 40, color: p.accent),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            SectionHeader(title: s.audioMessages),
            FutureBuilder<List<ContentCard>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Loading();
                if (snap.hasError) {
                  return ErrorRetry(
                    error: snap.error!,
                    onRetry: () => setState(() => _future = context.read<AppState>().api.contents(audioOnly: true)),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return EmptyState(message: s.noAudio, icon: Icon(Icons.headphones_rounded, size: 40, color: p.faint));
                }
                return Column(children: [
                  for (final item in items)
                    ContentRow(
                      item: item,
                      subtitle: [item.category.label(s.en), item.audioLength].whereType<String>().join(' · '),
                      trailing: item.isLocked
                          ? Icon(Icons.lock_outline_rounded, color: p.muted, size: 20)
                          : IconButton(
                              tooltip: s.play,
                              icon: Icon(Icons.play_circle_outline_rounded, color: p.accentText, size: 30),
                              onPressed: () async {
                                await audio.playSlug(item.slug);
                                if (context.mounted) push(context, const ListenScreen());
                              },
                            ),
                    ),
                ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// The small bar above the menu while something is playing.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioController>();
    final item = audio.current;
    if (item == null) return const SizedBox.shrink();
    final p = context.pal;
    final s = context.s;
    return Material(
      color: p.surfaceHi,
      child: InkWell(
        onTap: () => push(context, const ListenScreen()),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
          child: Row(children: [
            CrossIcon(size: 18, color: p.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: audio.playing ? s.pause : s.play,
              onPressed: audio.toggle,
              icon: Icon(audio.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: p.text),
            ),
          ]),
        ),
      ),
    );
  }
}
