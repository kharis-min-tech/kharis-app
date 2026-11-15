import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/bible_books.dart';
import '../../features/home/data/bible_repository.dart';
import 'bible_provider.dart';
import 'clock_provider.dart';
import 'onboarding_provider.dart';

/// The Bible chapter the member last opened, and the version they read it
/// in.
@immutable
class LastRead {
  const LastRead({
    required this.book,
    required this.chapter,
    required this.bibleId,
    required this.abbreviation,
    required this.openedAt,
  });

  /// USFM book code, e.g. `JHN`.
  final String book;
  final int chapter;

  /// YouVersion id and abbreviation of the version, e.g. 111 and `NIV`.
  final int bibleId;
  final String abbreviation;

  final DateTime openedAt;

  /// The chapter, as the reader's route and the passage providers take it.
  BibleLocation get location => BibleLocation(book, chapter);

  @override
  bool operator ==(Object other) =>
      other is LastRead &&
      other.book == book &&
      other.chapter == chapter &&
      other.bibleId == bibleId &&
      other.abbreviation == abbreviation &&
      other.openedAt == openedAt;

  @override
  int get hashCode =>
      Object.hash(book, chapter, bibleId, abbreviation, openedAt);
}

/// Remembers the last chapter opened in the reader, on this device, next to
/// the reading version ([SelectedBibleController]).
class LastReadController extends StateNotifier<LastRead?> {
  LastReadController(this._prefs, this._clock) : super(_load(_prefs));

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const String key = 'bible_last_read';

  static LastRead? _load(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final book = json['book'];
    final chapter = json['chapter'];
    final bibleId = json['bibleId'];
    final abbreviation = json['abbreviation'];
    final openedAt = json['openedAt'];
    if (book is! String ||
        chapter is! int ||
        bibleId is! int ||
        abbreviation is! String ||
        openedAt is! int) {
      return null;
    }
    // Only a real chapter of the 66-book canon is ever offered.
    final canon = kCanonBooks.where((b) => b.usfm == book).firstOrNull;
    if (canon == null || chapter < 1 || chapter > canon.chapters) return null;
    // A version the church no longer approves is never reopened.
    final approved = BibleRepository.approvedBibleIds.contains(bibleId);
    return LastRead(
      book: book,
      chapter: chapter,
      bibleId: approved ? bibleId : kDefaultBibleVersion.id,
      abbreviation: approved ? abbreviation : kDefaultBibleVersion.abbreviation,
      openedAt: DateTime.fromMillisecondsSinceEpoch(openedAt),
    );
  }

  /// Records that the chapter at [location] was opened in [version]. Any
  /// verse selection on [location] is left out: the place kept is a chapter.
  Future<void> save(BibleLocation location, BibleVersion version) async {
    final next = LastRead(
      book: location.usfm,
      chapter: location.chapter,
      bibleId: version.id,
      abbreviation: version.abbreviation,
      openedAt: _clock(),
    );
    state = next;
    await _prefs.setString(
      key,
      jsonEncode({
        'book': next.book,
        'chapter': next.chapter,
        'bibleId': next.bibleId,
        'abbreviation': next.abbreviation,
        'openedAt': next.openedAt.millisecondsSinceEpoch,
      }),
    );
  }
}

/// The last Bible chapter the member opened (book, chapter, version), or
/// null when they have not opened one. The reader calls
/// `ref.read(lastReadProvider.notifier).save(location, version)` each time a
/// chapter opens.
final lastReadProvider = StateNotifierProvider<LastReadController, LastRead?>(
  (ref) => LastReadController(
    ref.watch(sharedPreferencesProvider),
    ref.watch(clockProvider),
  ),
);
