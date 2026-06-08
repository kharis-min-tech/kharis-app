import 'package:just_audio/just_audio.dart';

import '../../../shared/models/sermon.dart';

/// Wraps [AudioPlayer] (just_audio) with a sermon-aware API.
///
/// Lifecycle: create once, dispose when the owning scope is destroyed.
/// The Riverpod provider calls [dispose] via [ref.onDispose].
class AudioPlayerService {
  AudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;
  Sermon? _currentSermon;

  // ── Accessors ──────────────────────────────────────────────────────────────

  Sermon? get currentSermon => _currentSermon;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // ── Playback control ───────────────────────────────────────────────────────

  /// Loads the sermon's audio URL and starts playback immediately.
  Future<void> play(Sermon sermon) async {
    _currentSermon = sermon;
    await _player.setUrl(sermon.audioUrl);
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  /// Resumes after a [pause]; no-op if already playing.
  Future<void> resume() => _player.play();

  /// Stops playback and releases the current audio source.
  Future<void> stop() async {
    await _player.stop();
    _currentSermon = null;
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() => _player.dispose();
}
