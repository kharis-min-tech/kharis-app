import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

enum NoteAnchorResult {
  /// Playback is running at the note's timestamp.
  started,

  /// The note is not anchored to a sermon position — nothing to seek to.
  notAnchored,

  /// The sermon the note was written against is no longer in the library.
  sermonUnavailable,

  /// The sermon exists but its audio would not load.
  playbackFailed,
}

/// Jumps playback back to the moment a note was written.
///
/// Used by both note surfaces — the overall list and the per-sermon sheet —
/// so "tap a note, hear what you were listening to" behaves identically.
abstract final class NoteAnchor {
  static Future<NoteAnchorResult> play(WidgetRef ref, Note note) async {
    final sermonId = note.sermonId;
    final positionMs = note.positionMs;
    if (sermonId == null || positionMs == null) {
      return NoteAnchorResult.notAnchored;
    }

    final audio = ref.read(audioPlayerServiceProvider);
    final target = Duration(milliseconds: positionMs);

    // Already loaded: play() attaches to the live source and seeks in place
    // rather than reloading. Matched through NoteTimelineKey, because the
    // note may be stored under the canonical `yt_` key while the loaded
    // variant carries its raw id.
    final playing = audio.currentSermon;
    final sermon =
        playing != null &&
            playing.hasAudio &&
            NoteTimelineKey.of(playing).matches(sermonId)
        ? playing
        : await _findSermon(ref, sermonId);
    if (sermon == null) return NoteAnchorResult.sermonUnavailable;

    // startAt wins over the saved resume point, and play() returns as soon
    // as the engine is running, so the caller can close its sheet right away.
    // A failed load must not read as started.
    if (!await audio.play(sermon, startAt: target, queue: audio.queue?.items)) {
      return NoteAnchorResult.playbackFailed;
    }
    return NoteAnchorResult.started;
  }

  /// The audio recording a note belongs to: the loaded library first, then
  /// the snapshots of recently played messages, which resolve before the
  /// archive has hydrated.
  static Future<Sermon?> _findSermon(WidgetRef ref, String sermonId) async {
    Sermon? match(Iterable<Sermon> sermons) {
      for (final sermon in sermons) {
        if (sermon.hasAudio && NoteTimelineKey.of(sermon).matches(sermonId)) {
          return sermon;
        }
      }
      return null;
    }

    try {
      final found = match(await ref.read(sermonsProvider.future));
      if (found != null) return found;
    } catch (_) {
      // Library unreachable: fall back to the snapshots below.
    }
    try {
      return match(ref.read(playbackHistoryProvider).snapshots());
    } catch (_) {
      return null;
    }
  }
}
