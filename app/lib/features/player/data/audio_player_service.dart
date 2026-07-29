import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// Wraps [AudioPlayer] (just_audio) with a sermon-aware API.
///
/// Lifecycle: create once, dispose when the owning scope is destroyed.
/// The Riverpod provider calls [dispose] via [ref.onDispose].
///
/// Playback resume: position is persisted to [CacheService] every ~5 s while
/// playing and immediately on pause/stop/dispose.  On [play], any saved
/// position > 10 s and more than 15 s before the end is restored so the
/// listener picks up where they left off.  A completed sermon resets to 0.
class AudioPlayerService {
  AudioPlayerService(this._cache) : _player = AudioPlayer() {
    _setupListeners();
  }

  final AudioPlayer _player;
  final CacheService _cache;
  Sermon? _currentSermon;

  /// Tracks last time a position was persisted; avoids hammering Hive.
  DateTime? _lastPositionSave;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  // ── Private helpers ────────────────────────────────────────────────────────

  void _setupListeners() {
    // Throttle-save position every ~5 s while actively playing.
    _positionSub = _player.positionStream.listen((pos) {
      final sermon = _currentSermon;
      if (sermon == null || !_player.playing) return;
      if (pos.inMilliseconds <= 10000) return;

      final now = DateTime.now();
      final last = _lastPositionSave;
      if (last == null || now.difference(last) >= const Duration(seconds: 5)) {
        _lastPositionSave = now;
        _cache.cachePlaybackPosition(sermon.id, pos.inMilliseconds);
      }
    });

    // Save on pause; clear on natural completion.
    _stateSub = _player.playerStateStream.listen((state) {
      final sermon = _currentSermon;
      if (sermon == null) return;

      if (state.processingState == ProcessingState.completed) {
        // Reset so the next play() starts from the beginning.
        _cache.cachePlaybackPosition(sermon.id, 0);
        return;
      }

      if (!state.playing) {
        final pos = _player.position;
        if (pos.inMilliseconds > 10000) {
          _cache.cachePlaybackPosition(sermon.id, pos.inMilliseconds);
          _lastPositionSave = DateTime.now();
        }
      }
    });
  }

  void _saveCurrentPosition() {
    final sermon = _currentSermon;
    if (sermon == null) return;
    final pos = _player.position;
    if (pos.inMilliseconds > 10000) {
      _cache.cachePlaybackPosition(sermon.id, pos.inMilliseconds);
      _lastPositionSave = DateTime.now();
    }
  }

  // ── Accessors ──────────────────────────────────────────────────────────────

  Sermon? get currentSermon => _currentSermon;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // ── Playback control ───────────────────────────────────────────────────────

  /// Loads the sermon's audio URL, seeks to any saved resume position, and
  /// starts playback immediately.
  Future<void> play(Sermon sermon) async {
    _currentSermon = sermon;
    _cache.addRecentlyPlayed(sermon.id);
    if (Firebase.apps.isNotEmpty) {
      // Fire-and-forget engagement event; never blocks playback.
      unawaited(FirebaseAnalytics.instance.logEvent(
        name: 'play_sermon',
        parameters: {
          'sermon_id': sermon.id,
          'title': sermon.title,
          'speaker': sermon.speaker,
        },
      ));
    }
    await _player.setUrl(
      sermon.audioUrl,
      headers: const {'User-Agent': kBrowserUserAgent},
    );

    // Restore saved position if it falls in the resumable window.
    final savedMs = _cache.getPlaybackPosition(sermon.id);
    final duration = _player.duration;
    if (savedMs > 10000 &&
        duration != null &&
        savedMs < duration.inMilliseconds - 15000) {
      await _player.seek(Duration(milliseconds: savedMs));
    }

    await _player.play();
  }

  /// Loads [sermon] paused at its saved resume position, without starting
  /// playback. Used on app launch to restore the minimised player where the
  /// listener left off.
  Future<void> loadPaused(Sermon sermon) async {
    _currentSermon = sermon;
    await _player.setUrl(
      sermon.audioUrl,
      headers: const {'User-Agent': kBrowserUserAgent},
    );
    final savedMs = _cache.getPlaybackPosition(sermon.id);
    final duration = _player.duration;
    if (savedMs > 10000 &&
        duration != null &&
        savedMs < duration.inMilliseconds - 15000) {
      await _player.seek(Duration(milliseconds: savedMs));
    }
  }

  /// Pauses playback; position is saved via the [playerStateStream] listener.
  Future<void> pause() => _player.pause();

  /// Resumes after a [pause]; no-op if already playing.
  Future<void> resume() => _player.play();

  /// Stops playback and releases the current audio source.
  ///
  /// Position is captured synchronously before the async stop so it is not
  /// lost if [_currentSermon] is cleared mid-teardown.
  Future<void> stop() async {
    _saveCurrentPosition();
    await _player.stop();
    _currentSermon = null;
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    // Flush position before tearing down subscriptions.
    if (_player.playing) _saveCurrentPosition();
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    await _player.dispose();
  }
}
