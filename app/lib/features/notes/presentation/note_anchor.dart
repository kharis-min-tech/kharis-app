import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
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

    // Already loaded: seek in place rather than reloading the source.
    if (audio.currentSermon?.id == sermonId) {
      await audio.seek(target);
      await audio.resume();
      return NoteAnchorResult.started;
    }

    final sermon = await _findSermon(ref, sermonId);
    if (sermon == null) return NoteAnchorResult.sermonUnavailable;

    // play() restores the saved resume point; seek afterwards so the note's
    // own timestamp wins.
    await audio.play(sermon);
    await audio.seek(target);
    return NoteAnchorResult.started;
  }

  static Future<Sermon?> _findSermon(WidgetRef ref, String sermonId) async {
    try {
      final sermons = await ref.read(sermonsProvider.future);
      for (final sermon in sermons) {
        if (sermon.id == sermonId && sermon.audioUrl.isNotEmpty) return sermon;
      }
    } catch (_) {
      // Library unreachable — treated the same as a missing sermon.
    }
    return null;
  }
}
