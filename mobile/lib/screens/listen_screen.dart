import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../audio/audio_controller.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';
import '../widgets/shell.dart';

String _fmt(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// The full-screen player from the template.
class ListenScreen extends StatelessWidget {
  const ListenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final audio = context.watch<AudioController>();
    final item = audio.current;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
            child: Column(children: [
              Row(children: [
                RoundButton(icon: const Icon(Icons.arrow_back_rounded), label: s.close, bare: true, onTap: () => Navigator.pop(context)),
                const Spacer(),
                if (item != null)
                  RoundButton(icon: const Icon(Icons.menu_book_rounded), label: s.read(null), bare: true, onTap: () => openReader(context, item.slug)),
              ]),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final side = (c.maxHeight * 0.9).clamp(0.0, c.maxWidth * 0.78);
                  return Center(
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Palette.gold.withValues(alpha: 0.8), width: 2),
                        boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 4)],
                      ),
                      child: ClipOval(child: AppImage(url: item?.coverImage, fallback: Img.audioCover)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              if (item == null)
                EmptyState(message: s.noAudio, icon: const Icon(Icons.headphones_rounded))
              else ...[
                Text(item.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 4),
                Text(item.authorName ?? item.category.label(s.en), style: TextStyle(fontSize: 14, color: p.muted)),
                if (audio.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s.audioFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 14),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _Progress(audio: audio)),
                const SizedBox(height: 8),
                _Controls(audio: audio),
                const SizedBox(height: 14),
                _Speeds(audio: audio),
                if (item.next != null) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: p.surface,
                    shape: StadiumBorder(side: BorderSide(color: p.border)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => audio.playSlug(item.next!.slug),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                            child: Text('${s.upNextShort}: ${item.next!.title}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: p.accentText),
                        ]),
                      ),
                    ),
                  ),
                ],
              ],
            ]),
          ),
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
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              overlayShape: SliderComponentShape.noOverlay,
              thumbColor: Palette.gold,
              activeTrackColor: Palette.gold,
              inactiveTrackColor: p.border,
            ),
            child: Slider(
              value: pos.inMilliseconds.clamp(0, max).toDouble(),
              max: max,
              onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_fmt(pos), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.muted)),
            Text(_fmt(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.muted)),
          ]),
        ]);
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.audio});
  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    Widget skip(int secs, String label) => IconButton(
          tooltip: label,
          iconSize: 40,
          onPressed: () => audio.skip(secs),
          icon: Stack(alignment: Alignment.center, children: [
            Transform.flip(flipX: secs > 0, child: Icon(Icons.replay_rounded, color: p.text, size: 40)),
            Padding(padding: const EdgeInsets.only(top: 3), child: Text('15', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: p.text))),
          ]),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      skip(-15, s.rewind15),
      const SizedBox(width: 22),
      StreamBuilder<PlayerState>(
        stream: audio.player.playerStateStream,
        builder: (context, snap) {
          final state = snap.data;
          final busy = audio.loading || state?.processingState == ProcessingState.loading || state?.processingState == ProcessingState.buffering;
          final playing = state?.playing ?? false;
          return Semantics(
            button: true,
            label: playing ? s.pause : s.play,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: audio.toggle,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: Palette.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.45), blurRadius: 22)],
                ),
                child: Center(
                  child: busy
                      ? SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: p.onAccent))
                      : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 48, color: p.onAccent),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(width: 22),
      skip(15, s.forward15),
    ]);
  }
}

class _Speeds extends StatelessWidget {
  const _Speeds({required this.audio});
  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Semantics(
      label: s.speed,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final v in [1.0, 1.25, 1.5])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => audio.setSpeed(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minWidth: 56, minHeight: 40),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: audio.speed == v ? Palette.goldGradient : null,
                  borderRadius: BorderRadius.circular(18),
                  border: audio.speed == v ? null : Border.all(color: p.border),
                ),
                child: Text('${v.toString().replaceAll(RegExp(r'0$'), '').replaceAll(RegExp(r'\.$'), '.0')}x',
                    style: TextStyle(fontWeight: FontWeight.w800, color: audio.speed == v ? p.onAccent : p.text)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The Listen tab: what is playing, and every message with audio.
class ListenTab extends StatelessWidget {
  const ListenTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    final api = context.read<AppState>().api;
    final audio = context.watch<AudioController>();
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
          child: LiveData<List<ContentCard>>(
            load: () => api.contents(audioOnly: true),
            builder: (context, items, reload) => RefreshIndicator(
              color: p.accent,
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
                const AppTopBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Text(s.listen, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ),
                if (audio.current != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Material(
                      color: p.surfaceHi,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: p.accent)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => push(context, const ListenScreen()),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            ClipOval(child: AppImage(url: audio.current!.coverImage, fallback: Img.audioCover, width: 58, height: 58)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.nowPlayingFrom, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: p.accentText)),
                                Text(audio.current!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                              ]),
                            ),
                            _GoldPlay(audio: audio),
                          ]),
                        ),
                      ),
                    ),
                  ),
                SectionHeader(title: s.audioMessages),
                if (items.isEmpty)
                  EmptyState(message: s.noAudio, icon: const Icon(Icons.headphones_rounded))
                else
                  for (final item in items)
                    ContentRow(
                      item: item,
                      subtitle: [item.category.label(s.en), item.audioLength].whereType<String>().join(' · '),
                      trailing: item.isLocked
                          ? Icon(Icons.lock_rounded, color: p.muted, size: 20)
                          : IconButton(
                              tooltip: s.play,
                              icon: Icon(Icons.play_circle_fill_rounded, color: p.accent, size: 38),
                              onPressed: () async {
                                await audio.playSlug(item.slug);
                                if (context.mounted) push(context, const ListenScreen());
                              },
                            ),
                    ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldPlay extends StatelessWidget {
  const _GoldPlay({required this.audio});
  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Semantics(
      button: true,
      label: audio.playing ? s.pause : s.play,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: audio.toggle,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(gradient: Palette.goldGradient, shape: BoxShape.circle),
          child: Icon(audio.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: context.pal.onAccent, size: 28),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.surfaceHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => push(context, const ListenScreen()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: AppImage(url: item.coverImage, fallback: Img.audioCover, width: 44, height: 44)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(item.authorName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
                ]),
              ),
              _GoldPlay(audio: audio),
            ]),
          ),
        ),
      ),
    );
  }
}
