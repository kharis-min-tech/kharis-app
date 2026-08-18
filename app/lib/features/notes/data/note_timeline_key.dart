import 'package:flutter/foundation.dart';

import 'package:kharis_app/shared/models/sermon.dart';

/// The key a [Note] is stored under — one shared timeline per message,
/// however many [Sermon] variants that message surfaces as.
///
/// The same physical message can reach the player as up to three different
/// [Sermon] objects, each with a different `id`:
///
///  - the Kharis API mp3 (numeric id, e.g. `2611`), which usually also
///    carries the YouTube `videoId` of the same recording;
///  - the Firestore CMS doc synced from YouTube, whose doc id is
///    `yt_<videoId>` (see backend/functions/src/sync-youtube.ts);
///  - the raw YouTube feed entry, whose id is the bare `<videoId>`.
///
/// Keying notes on the raw `Sermon.id` split one message's notes across
/// three stores. The CANONICAL note key is therefore:
///
///  - **`yt_<videoId>`** whenever the message has a video — the videoId is
///    the only identity stable across every source, and this spelling
///    matches the CMS doc id convention;
///  - **the sermon's own id** for audio-only messages.
///
/// New notes are written under [canonical]; reads accept the legacy aliases
/// (raw sermon id, bare videoId) via [matches] so notes written before this
/// key existed stay on the timeline.
///
/// [matches] can only accept aliases DERIVABLE from the variant on screen. A
/// legacy note keyed under the numeric API id of a message opened via its
/// `yt_`/feed variant is resolved one level up: `sermonNotesProvider` scans
/// the loaded catalogue for sermons sharing this key's [canonical] and
/// accepts their raw ids too.
@immutable
class NoteTimelineKey {
  const NoteTimelineKey(this.sermonId, {this.videoId});

  NoteTimelineKey.of(Sermon sermon)
      : this(
          sermon.id,
          videoId: sermon.hasVideo ? sermon.videoId!.trim() : null,
        );

  /// The raw id of the sermon variant on screen.
  final String sermonId;

  /// The YouTube video id shared by every variant of this message, when the
  /// message has a video.
  final String? videoId;

  /// The key new notes are written under.
  String get canonical => videoId != null ? 'yt_$videoId' : sermonId;

  /// Whether a note stored under [noteSermonId] belongs to this message —
  /// canonical key or any legacy alias.
  bool matches(String? noteSermonId) {
    if (noteSermonId == null) return false;
    if (noteSermonId == sermonId || noteSermonId == canonical) return true;
    final video = videoId;
    return video != null && noteSermonId == video;
  }

  @override
  bool operator ==(Object other) =>
      other is NoteTimelineKey &&
      other.sermonId == sermonId &&
      other.videoId == videoId;

  @override
  int get hashCode => Object.hash(sermonId, videoId);
}
