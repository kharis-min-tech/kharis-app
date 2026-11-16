import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/data/bible_reference.dart';
import '../../features/home/data/bible_repository.dart';
import '../models/sermon.dart';
import 'sermon_provider.dart';

/// A run of verses in one chapter that a message is preached from.
typedef _Range = ({int start, int end, Sermon sermon});

/// The messages preached from the verses of one chapter.
@immutable
class RelatedMessages {
  const RelatedMessages._(this._ranges);

  /// A chapter no message names.
  static const RelatedMessages none = RelatedMessages._([]);

  /// Newest message first.
  final List<_Range> _ranges;

  bool get isEmpty => _ranges.isEmpty;

  /// Whether any message is preached from [verse].
  bool has(int verse) =>
      _ranges.any((r) => verse >= r.start && verse <= r.end);

  /// The messages preached from [verse], newest first, each once.
  List<Sermon> forVerse(int verse) {
    final seen = <String>{};
    return [
      for (final r in _ranges)
        if (verse >= r.start && verse <= r.end && seen.add(r.sermon.id))
          r.sermon,
    ];
  }
}

/// The passages each `Sermon.passages` string names, parsed once per string
/// for the life of the app: the library re-emits as its pages land.
final _parsedPassagesProvider = Provider<Map<String, List<BibleLocation>>>(
  (ref) => {},
);

/// Every verse range the library's messages name, by chapter id (`JHN.3`),
/// newest message first.
///
/// A passage counts when it parses, through `bible_reference.dart`, to
/// verses of a chapter in the 66-book canon ("Acts 20:17-38"). A passage
/// that names a whole chapter ("Romans 8") or does not parse marks no verse.
final _relatedIndexProvider = Provider<Map<String, List<_Range>>>((ref) {
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  final parsed = ref.watch(_parsedPassagesProvider);
  final canon = BibleIndex.bundled();
  final newestFirst = [
    for (final s in sermons)
      if (s.passages.isNotEmpty) s,
  ]..sort(
    (a, b) =>
        (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)),
  );

  final index = <String, List<_Range>>{};
  for (final sermon in newestFirst) {
    for (final passage in sermon.passages) {
      final locations = parsed[passage] ??= parseReadingReferences(
        passage,
        canon,
      );
      for (final at in locations) {
        final start = at.verseStart;
        if (start == null) continue;
        (index[at.passageId] ??= []).add((
          start: start,
          end: at.verseEnd ?? start,
          sermon: sermon,
        ));
      }
    }
  }
  return index;
});

/// The messages preached from the verses of one chapter (`book` is the USFM
/// code), looked up from `Sermon.passages` and kept per chapter.
final relatedMessagesProvider =
    Provider.family<RelatedMessages, ({String book, int chapter})>((ref, at) {
      final ranges = ref.watch(
        _relatedIndexProvider.select(
          (index) => index['${at.book}.${at.chapter}'],
        ),
      );
      return ranges == null ? RelatedMessages.none : RelatedMessages._(ranges);
    });
