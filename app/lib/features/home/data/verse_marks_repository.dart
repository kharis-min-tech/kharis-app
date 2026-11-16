import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';

/// One verse, named the way the Bible API names it.
@immutable
class VerseRef {
  const VerseRef(this.book, this.chapter, this.verse);

  /// USFM book code, e.g. `JHN`.
  final String book;
  final int chapter;
  final int verse;

  /// `JHN.3.16`: what marks are keyed by, the same in every version.
  String get usfm => '$book.$chapter.$verse';

  /// `JHN.3`, the chapter's passage id.
  String get chapterId => '$book.$chapter';

  /// "John 3:16": the full book name and a colon.
  String get reference {
    final name = kCanonBooks
        .where((b) => b.usfm == book)
        .map((b) => b.name)
        .firstOrNull;
    return '${name ?? book} $chapter:$verse';
  }

  /// The verse as a place the reader can open and scroll to.
  BibleLocation get location =>
      BibleLocation(book, chapter, verseStart: verse, verseEnd: verse);

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(book, chapter, verse);

  @override
  String toString() => usfm;
}

/// A highlighted verse. The highlight belongs to the verse, whatever version
/// is on screen; [text] and [version] are what the member was reading when
/// they made it, for the Highlights list.
@immutable
class VerseHighlight {
  const VerseHighlight({
    required this.ref,
    required this.colour,
    required this.text,
    required this.version,
    required this.markedAt,
  });

  final VerseRef ref;

  /// 1 or 2: the theme's `verseHighlight1` or `verseHighlight2`.
  final int colour;

  /// The verse's words, shortened to [VerseMarksRepository.snippetLength].
  final String text;

  /// Abbreviation of the version [text] is from, e.g. `NIV`.
  final String version;

  final DateTime markedAt;
}

/// The member's note on a verse. It keeps the version it was written in.
@immutable
class VerseNote {
  const VerseNote({
    required this.ref,
    required this.body,
    required this.text,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final VerseRef ref;

  /// What the member wrote.
  final String body;

  /// The verse's words when the note was first written, shortened to
  /// [VerseMarksRepository.snippetLength].
  final String text;

  /// Abbreviation of the version the note was written in, e.g. `NIV`.
  final String version;

  final DateTime createdAt;
  final DateTime updatedAt;
}

/// The marks on one chapter, by verse number.
@immutable
class ChapterMarks {
  const ChapterMarks({this.highlights = const {}, this.notes = const {}});

  final Map<int, VerseHighlight> highlights;
  final Map<int, VerseNote> notes;

  bool get isEmpty => highlights.isEmpty && notes.isEmpty;
}

/// Verse highlights and verse notes, kept on this device.
///
/// Each chapter's marks are one small [CacheService] preference
/// (`verse_marks.JHN.3`), so opening a chapter reads one entry and marking a
/// verse rewrites only that chapter. `verse_marks.chapters` lists the
/// chapters that have any, for the Highlights and My notes lists.
///
/// Verse notes are not the message notes of `NoteRepository`: that model is
/// a notepad per message, synced under the member's account, and has no
/// place for a verse. These stay on the phone.
class VerseMarksRepository {
  VerseMarksRepository(this._cache, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final CacheService _cache;
  final DateTime Function() _clock;

  static const String _prefix = 'verse_marks.';

  /// Preference key of the chapters that carry marks, as a JSON list.
  static const String chaptersKey = '${_prefix}chapters';

  /// Longest verse text kept with a mark; longer text ends with an ellipsis.
  static const int snippetLength = 200;

  /// Bumped on every change.
  final ValueNotifier<int> changes = ValueNotifier(0);

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// The marks on [chapter] of [book] (a USFM code).
  ChapterMarks chapter(String book, int chapter) {
    final raw = _cache.getPreference<Object?>('$_prefix$book.$chapter', null);
    if (raw is! String) return const ChapterMarks();
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const ChapterMarks();
    }
    if (json is! Map) return const ChapterMarks();
    final highlights = <int, VerseHighlight>{};
    final notes = <int, VerseNote>{};
    void each(
      Object? group,
      void Function(VerseRef ref, Map<dynamic, dynamic> m) add,
    ) {
      if (group is! Map) return;
      for (final entry in group.entries) {
        final verse = int.tryParse('${entry.key}');
        final value = entry.value;
        if (verse == null || value is! Map) continue;
        add(VerseRef(book, chapter, verse), value);
      }
    }

    each(json['h'], (ref, m) {
      final colour = m['c'];
      final at = m['at'];
      if ((colour != 1 && colour != 2) || at is! int) return;
      highlights[ref.verse] = VerseHighlight(
        ref: ref,
        colour: colour as int,
        text: m['t'] as String? ?? '',
        version: m['v'] as String? ?? '',
        markedAt: DateTime.fromMillisecondsSinceEpoch(at),
      );
    });
    each(json['n'], (ref, m) {
      final body = m['b'];
      final created = m['c'];
      final updated = m['u'];
      if (body is! String || created is! int || updated is! int) return;
      notes[ref.verse] = VerseNote(
        ref: ref,
        body: body,
        text: m['t'] as String? ?? '',
        version: m['v'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(created),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updated),
      );
    });
    return ChapterMarks(highlights: highlights, notes: notes);
  }

  /// Every highlight, most recently made first.
  List<VerseHighlight> highlights() =>
      [for (final marks in _allChapters()) ...marks.highlights.values]
        ..sort((a, b) => b.markedAt.compareTo(a.markedAt));

  /// Every verse note, most recently edited first.
  List<VerseNote> notes() =>
      [for (final marks in _allChapters()) ...marks.notes.values]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Highlights [ref] in [colour] (1 or 2), replacing any highlight it has.
  /// [text] is the verse as shown, in the version abbreviated [version].
  void setHighlight(
    VerseRef ref,
    int colour, {
    required String text,
    required String version,
  }) {
    if (colour != 1 && colour != 2) {
      throw ArgumentError.value(colour, 'colour', 'must be 1 or 2');
    }
    _update(ref, (marks) {
      marks.highlights[ref.verse] = VerseHighlight(
        ref: ref,
        colour: colour,
        text: _snippet(text),
        version: version,
        markedAt: _clock(),
      );
    });
  }

  /// Removes [ref]'s highlight, if it has one.
  void clearHighlight(VerseRef ref) =>
      _update(ref, (marks) => marks.highlights.remove(ref.verse));

  /// Saves the member's note on [ref]: one note per verse. An empty [body]
  /// removes the note. A note that is edited keeps the verse text, version
  /// and date it was first written with.
  void saveNote(
    VerseRef ref,
    String body, {
    required String text,
    required String version,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return deleteNote(ref);
    _update(ref, (marks) {
      final existing = marks.notes[ref.verse];
      final now = _clock();
      marks.notes[ref.verse] = VerseNote(
        ref: ref,
        body: trimmed,
        text: existing?.text ?? _snippet(text),
        version: existing?.version ?? version,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
    });
  }

  /// Removes [ref]'s note, if it has one.
  void deleteNote(VerseRef ref) =>
      _update(ref, (marks) => marks.notes.remove(ref.verse));

  // ── Internals ──────────────────────────────────────────────────────────────

  void _update(VerseRef ref, void Function(ChapterMarks marks) change) {
    final stored = chapter(ref.book, ref.chapter);
    final marks = ChapterMarks(
      highlights: Map.of(stored.highlights),
      notes: Map.of(stored.notes),
    );
    change(marks);
    _cache.cachePreference(
      '$_prefix${ref.chapterId}',
      marks.isEmpty ? null : jsonEncode(_encode(marks)),
    );
    final chapters = _chapterIds();
    final listed = chapters.contains(ref.chapterId);
    if (listed == marks.isEmpty) {
      marks.isEmpty
          ? chapters.remove(ref.chapterId)
          : chapters.add(ref.chapterId);
      _cache.cachePreference(chaptersKey, jsonEncode(chapters));
    }
    changes.value++;
  }

  static Map<String, dynamic> _encode(ChapterMarks marks) => {
    'h': {
      for (final h in marks.highlights.values)
        '${h.ref.verse}': {
          'c': h.colour,
          't': h.text,
          'v': h.version,
          'at': h.markedAt.millisecondsSinceEpoch,
        },
    },
    'n': {
      for (final n in marks.notes.values)
        '${n.ref.verse}': {
          'b': n.body,
          't': n.text,
          'v': n.version,
          'c': n.createdAt.millisecondsSinceEpoch,
          'u': n.updatedAt.millisecondsSinceEpoch,
        },
    },
  };

  List<String> _chapterIds() {
    final raw = _cache.getPreference<Object?>(chaptersKey, null);
    if (raw is! String) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.whereType<String>().toList() : [];
    } on FormatException {
      return [];
    }
  }

  Iterable<ChapterMarks> _allChapters() sync* {
    for (final id in _chapterIds()) {
      final dot = id.lastIndexOf('.');
      final number = dot < 0 ? null : int.tryParse(id.substring(dot + 1));
      if (number != null) yield chapter(id.substring(0, dot), number);
    }
  }

  static String _snippet(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= snippetLength) return clean;
    final cut = clean.substring(0, snippetLength);
    final space = cut.lastIndexOf(' ');
    return '${(space > 0 ? cut.substring(0, space) : cut).trimRight()}…';
  }
}
