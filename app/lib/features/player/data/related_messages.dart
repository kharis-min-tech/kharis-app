import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// Most messages the player's "More like this" rail offers.
const int kRelatedMessagesLimit = 10;

/// Kharis messages to suggest after [current], drawn only from [library]
/// (the app's own catalogue; nothing is searched for elsewhere).
///
/// In order, until [limit]:
/// 1. the messages the Kharis sermon site lists as related
///    ([Sermon.relatedIds]), in the site's order;
/// 2. the rest of [current]'s series, nearest in date first;
/// 3. more from the same speaker, newest first.
///
/// Every variant of [current] in the library (API mp3, `yt_` CMS doc)
/// contributes: a CMS copy without a series or site picks still gets its
/// API twin's. Each suggestion appears once, whichever variants the library
/// holds of it, and never [current] itself or a variant of it. Shorts and
/// entries with nothing to play are skipped.
List<Sermon> relatedMessages(
  Sermon current,
  List<Sermon> library, {
  int limit = kRelatedMessagesLimit,
}) {
  final currentKey = _messageKey(current);
  final seen = <String>{currentKey, current.id};
  final picked = <Sermon>[];

  void take(Iterable<Sermon> candidates) {
    for (final s in candidates) {
      if (picked.length >= limit) return;
      if (s.isShortClip || !(s.hasAudio || s.hasVideo)) continue;
      final key = _messageKey(s);
      if (seen.contains(s.id) || seen.contains(key)) continue;
      seen
        ..add(s.id)
        ..add(key);
      picked.add(s);
    }
  }

  // Every variant of the message on screen, the one on screen first.
  final variants = [
    current,
    for (final s in library)
      if (s.id != current.id && _messageKey(s) == currentKey) s,
  ];

  // 1. The site's own picks.
  final byId = <String, Sermon>{};
  for (final s in library) {
    byId.putIfAbsent(s.id, () => s);
  }
  final relatedIds = <String>{for (final v in variants) ...v.relatedIds};
  take([for (final id in relatedIds) ?byId[id]]);

  // 2. The same series, nearest in date.
  final series = _first(variants.map((v) => _norm(v.series)));
  if (series.isNotEmpty) {
    final when = variants.map((v) => v.publishedAt).nonNulls.firstOrNull;
    final inSeries = _indexed(library.where((s) => _norm(s.series) == series));
    inSeries.sort((a, b) {
      final byDistance = _compareNullsLast(
        _distance(a.$2.publishedAt, when),
        _distance(b.$2.publishedAt, when),
      );
      return byDistance != 0 ? byDistance : a.$1.compareTo(b.$1);
    });
    take(inSeries.map((e) => e.$2));
  }

  // 3. The same speaker, newest first.
  final speaker = _first(variants.map((v) => _norm(v.speaker)));
  if (speaker.isNotEmpty) {
    final bySpeaker = _indexed(
      library.where((s) => _norm(s.speaker) == speaker),
    );
    bySpeaker.sort((a, b) {
      final byDate = _compareNullsLast(
        _newestFirst(a.$2.publishedAt),
        _newestFirst(b.$2.publishedAt),
      );
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
    take(bySpeaker.map((e) => e.$2));
  }

  return List.unmodifiable(picked);
}

/// The first non-empty of [values], or empty.
String _first(Iterable<String> values) =>
    values.firstWhere((v) => v.isNotEmpty, orElse: () => '');

/// One key per physical message, shared by its variants (see
/// [NoteTimelineKey.canonical]).
String _messageKey(Sermon s) => NoteTimelineKey.of(s).canonical;

String _norm(String? value) => (value ?? '').trim().toLowerCase();

/// Pairs each sermon with its library position: [List.sort] is not stable,
/// so ties fall back to the library's order explicitly.
List<(int, Sermon)> _indexed(Iterable<Sermon> sermons) {
  var i = 0;
  return [for (final s in sermons) (i++, s)];
}

/// How far apart two dates are, or null when either is unknown.
int? _distance(DateTime? a, DateTime? b) {
  if (a == null || b == null) return null;
  return a.difference(b).inMinutes.abs();
}

/// A sort key that puts later dates first; null when unknown.
int? _newestFirst(DateTime? date) =>
    date == null ? null : -date.millisecondsSinceEpoch;

/// Ascending, with unknown values after every known one.
int _compareNullsLast(int? a, int? b) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
