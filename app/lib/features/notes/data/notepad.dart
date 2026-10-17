import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

import 'package:kharis_app/core/utils/playback_timestamp.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/shared/models/sermon.dart';

// A member's notes on one message are ONE notepad: a single Note keyed to the
// message (`positionMs` null) whose body is free text. Moments in the message
// are written into that text as timestamp tokens — `[12:34]`, `[1:02:07]` —
// spelled by formatPlaybackTimestamp, so the notepad stays plain text that
// syncs, previews and searches like any other note while the app renders each
// token as a tappable seek.

/// Firestore rejects note bodies longer than this (backend/firestore.rules),
/// so the notepad stops accepting input at it.
const int notepadMaxLength = 20000;

/// `[m:ss]` or `[h:mm:ss]`. Range checks live in [findNoteTimestamps].
final RegExp _token = RegExp(r'\[(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\]');

/// One timestamp token inside a note body: the text range it occupies and the
/// moment in the message it points at.
@immutable
class NoteTimestamp {
  const NoteTimestamp(this.start, this.end, this.position);

  /// Offset of the opening `[`.
  final int start;

  /// Offset just past the closing `]`.
  final int end;

  final Duration position;

  @override
  bool operator ==(Object other) =>
      other is NoteTimestamp &&
      other.start == start &&
      other.end == end &&
      other.position == position;

  @override
  int get hashCode => Object.hash(start, end, position);

  @override
  String toString() => 'NoteTimestamp($start-$end @ $position)';
}

/// The token written for [position]: `[12:34]`, `[1:02:07]`.
String noteTimestampToken(Duration position) =>
    '[${formatPlaybackTimestamp(position)}]';

/// Every well-formed timestamp token in [text], in reading order. Minutes and
/// seconds past 59 are not timestamps (`[75:00]` stays plain text), so a
/// bracketed figure the member typed for another reason is left alone.
List<NoteTimestamp> findNoteTimestamps(String text) {
  final found = <NoteTimestamp>[];
  for (final match in _token.allMatches(text)) {
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    if (minutes > 59 || seconds > 59) continue;
    found.add(
      NoteTimestamp(
        match.start,
        match.end,
        Duration(hours: hours, minutes: minutes, seconds: seconds),
      ),
    );
  }
  return found;
}

/// Every moment [note] marks on its message: its legacy `positionMs` anchor
/// and each token in its body. Drives the seek-bar pins.
List<Duration> noteMoments(Note note) => [
  if (note.positionMs case final ms?) Duration(milliseconds: ms),
  for (final stamp in findNoteTimestamps(note.body)) stamp.position,
];

/// [value] with a token for [position] inserted at the cursor.
///
/// A selection is kept, not replaced: the token goes in front of it. With no
/// cursor (the field was never focused) the token starts a fresh line at the
/// end. A space separates it from a word on either side, and the cursor lands
/// after that space, ready to type.
TextEditingValue insertNoteTimestamp(
  TextEditingValue value,
  Duration position,
) {
  final text = value.text;
  final selection = value.selection;
  final hasCursor = selection.isValid;
  final at = hasCursor ? selection.start : text.length;
  final before = text.substring(0, at);
  final after = text.substring(at);

  final lead = before.isEmpty || RegExp(r'\s$').hasMatch(before)
      ? ''
      : (hasCursor ? ' ' : '\n');
  final trailingSpace = after.startsWith(' ');
  final inserted =
      '$lead${noteTimestampToken(position)}${trailingSpace ? '' : ' '}';
  final caret = at + inserted.length + (trailingSpace ? 1 : 0);
  return TextEditingValue(
    text: '$before$inserted$after',
    selection: TextSelection.collapsed(offset: caret),
  );
}

/// What a message's notepad opens with.
@immutable
class NotepadDraft {
  const NotepadDraft({
    required this.pad,
    required this.body,
    required this.replaces,
  });

  /// The note kept as the notepad — the oldest note with no position — or
  /// null when the message has none yet (a new id is minted on first save).
  final Note? pad;

  /// The notepad text: [pad] and every other note on the message folded in.
  final String body;

  /// The other notes folded into [body]. They are deleted once the notepad
  /// has been saved — never before, so a failed save loses nothing.
  final List<String> replaces;
}

/// Folds every note on one message into a single notepad.
///
/// Older builds wrote one note per moment. Those notes are merged lazily the
/// first time the notepad is opened or saved: notes with no position (an
/// earlier notepad, or a note tagged to the message while it was not playing)
/// come first, oldest first; each timed note follows in timeline order as a
/// `[m:ss] text` line.
///
/// Idempotent: a timed note whose line is already in the notepad — merged by
/// an earlier save whose clean-up never landed — is not appended twice, but
/// is still listed in [NotepadDraft.replaces] so the next save retires it.
NotepadDraft composeNotepad(Iterable<Note> notes) {
  final free = notes.where((n) => n.positionMs == null).toList()
    ..sort((a, b) {
      final byAge = a.createdAt.compareTo(b.createdAt);
      return byAge != 0 ? byAge : a.id.compareTo(b.id);
    });
  final timed = notes.where((n) => n.positionMs != null).toList()
    ..sort((a, b) {
      final byTime = a.positionMs!.compareTo(b.positionMs!);
      return byTime != 0 ? byTime : a.createdAt.compareTo(b.createdAt);
    });

  final pad = free.isEmpty ? null : free.first;
  if (pad != null && free.length == 1 && timed.isEmpty) {
    return NotepadDraft(pad: pad, body: pad.body, replaces: const []);
  }

  final lines = <String>[];
  bool alreadyIn(String chunk) => lines.any((line) => line.contains(chunk));

  for (final note in free) {
    final body = note.body.trimRight();
    if (body.trim().isEmpty) continue;
    if (note != pad && alreadyIn(body.trim())) continue;
    lines.add(body);
  }
  for (final note in timed) {
    final body = note.body.trim();
    final line =
        '${noteTimestampToken(Duration(milliseconds: note.positionMs!))}'
        '${body.isEmpty ? '' : ' $body'}';
    if (alreadyIn(line)) continue;
    lines.add(line);
  }

  return NotepadDraft(
    pad: pad,
    body: lines.join('\n'),
    replaces: [
      for (final note in [...free, ...timed])
        if (note != pad) note.id,
    ],
  );
}

/// One entry in the member's notebook: a message's notepad — everything
/// written on that message, folded — or a general note.
@immutable
class NotebookEntry {
  const NotebookEntry._(this.messageKey, this.notes);

  /// The key the message's notes share; null for a general note.
  final String? messageKey;

  /// The notes behind this entry: a general note alone, or every note on the
  /// message.
  final List<Note> notes;

  bool get isMessage => messageKey != null;

  /// The message's title as stored with its notes, newest first.
  String? get title {
    for (final note in _newestFirst) {
      if (note.sermonTitle case final title?) return title;
    }
    return null;
  }

  DateTime get updatedAt => _newestFirst.first.updatedAt;

  /// What the entry reads as: the composed notepad, or the general note.
  String get text => isMessage ? composeNotepad(notes).body : notes.single.body;

  List<Note> get _newestFirst =>
      [...notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

/// The notebook: one entry per message, however many notes and id variants
/// it has, plus one per general note — newest edit first.
///
/// Notes are grouped on their message's canonical key. A legacy note stored
/// under a variant's raw id joins the group when [catalogue] links that id
/// to the canonical key (see `sermonNotesProvider`); without the catalogue
/// it stands under its own key until the library loads.
List<NotebookEntry> groupNotebook(
  Iterable<Note> notes,
  Iterable<Sermon> catalogue,
) {
  final canonicalOf = <String, String>{};
  for (final sermon in catalogue) {
    final key = NoteTimelineKey.of(sermon);
    canonicalOf[sermon.id] = key.canonical;
    canonicalOf[key.canonical] = key.canonical;
    if (key.videoId case final video?) canonicalOf[video] = key.canonical;
  }

  final byMessage = <String, List<Note>>{};
  final entries = <NotebookEntry>[];
  for (final note in notes) {
    final id = note.sermonId;
    if (id == null) {
      entries.add(NotebookEntry._(null, [note]));
    } else {
      byMessage.putIfAbsent(canonicalOf[id] ?? id, () => []).add(note);
    }
  }
  for (final MapEntry(:key, :value) in byMessage.entries) {
    entries.add(NotebookEntry._(key, value));
  }
  return entries..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
