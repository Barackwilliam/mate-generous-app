import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// One player for the whole app: keeps playing in the background with
/// lock-screen and notification controls (just_audio_background), and
/// remembers where the listener stopped.
class AudioController extends ChangeNotifier {
  AudioController(this.api, {AudioPlayer Function()? playerFactory}) : _factory = playerFactory ?? AudioPlayer.new;

  final ApiClient api;
  final AudioPlayer Function() _factory;
  AudioPlayer? _player;
  ContentDetail? current;
  bool loading = false;
  String? error;
  Timer? _saveTimer;
  final _subs = <StreamSubscription>[];

  static const speeds = [1.0, 1.25, 1.5, 0.75];

  AudioPlayer get player => _player ??= _create();

  AudioPlayer _create() {
    final p = _factory();
    _subs.add(p.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _saveProgress(finished: true);
      notifyListeners();
    }));
    _saveTimer = Timer.periodic(const Duration(seconds: 20), (_) => _saveProgress());
    return p;
  }

  bool get hasPlayer => _player != null && current != null;
  bool get playing => _player?.playing ?? false;
  double get speed => _player?.speed ?? 1.0;

  Future<void> play(ContentDetail item) async {
    if (current?.slug == item.slug && _player != null) {
      await player.play();
      return;
    }
    await _saveProgress();
    current = item;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final url = await api.audioUrl(item.slug);
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: item.slug,
            title: item.title,
            artist: item.authorName ?? 'Kesha la Usiku',
            album: item.seriesTitle ?? item.category.name,
            duration: item.audioSeconds == null ? null : Duration(seconds: item.audioSeconds!),
          ),
        ),
        initialPosition: Duration(seconds: item.audioPosition),
      );
      loading = false;
      notifyListeners();
      await player.play();
    } catch (e) {
      loading = false;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggle() async => playing ? player.pause() : player.play();

  Future<void> skip(int seconds) async {
    final p = player;
    final target = p.position + Duration(seconds: seconds);
    final max = p.duration ?? target;
    await p.seek(target < Duration.zero ? Duration.zero : (target > max ? max : target));
  }

  Future<void> cycleSpeed() async {
    final i = speeds.indexOf(speed);
    await player.setSpeed(speeds[(i + 1) % speeds.length]);
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    await player.setSpeed(value);
    notifyListeners();
  }

  Future<void> playSlug(String slug) async => play(await api.content(slug));

  Future<void> _saveProgress({bool finished = false}) async {
    final item = current;
    final p = _player;
    if (item == null || p == null || !api.isSignedIn) return;
    final secs = p.position.inSeconds;
    if (secs <= 0 && !finished) return;
    try {
      await api.reportProgress(item.slug, audioSeconds: secs, percent: finished ? 100 : null);
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }
}
