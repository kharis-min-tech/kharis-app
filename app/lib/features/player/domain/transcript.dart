import 'package:flutter/foundation.dart';

/// One stretch of a transcript: the words spoken from [start] until the next
/// segment begins.
@immutable
class TranscriptSegment {
  const TranscriptSegment({required this.start, required this.text});

  /// Where the stretch begins on the message's AUDIO timeline (the video
  /// engine maps its clock through `Sermon.videoStart` before comparing).
  /// Null for text that carries no timestamp: a preamble before the first
  /// marker, or a transcript without markers at all.
  final Duration? start;

  /// The spoken words, whitespace collapsed to single spaces.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is TranscriptSegment && other.start == start && other.text == text;

  @override
  int get hashCode => Object.hash(start, text);

  @override
  String toString() => 'TranscriptSegment($start, $text)';
}

/// One search hit: the code-unit range [start, end) inside
/// `segments[segment].text`.
@immutable
class TranscriptMatch {
  const TranscriptMatch(this.segment, this.start, this.end);

  final int segment;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is TranscriptMatch &&
      other.segment == segment &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(segment, start, end);

  @override
  String toString() => 'TranscriptMatch($segment, $start, $end)';
}

/// A message transcript split at its timestamp markers.
///
/// The transcript files (written by the Cloudflare worker's
/// `fetchTranscriptText`) are plain text that opens at the first `[m:ss]`
/// marker and carries `[m:ss]` / `[mm:ss]` / `[h:mm:ss]` markers through the
/// text, each opening the words spoken from that moment. Markers are emitted
/// in timeline order by the transcriber; [segmentAt] relies on that.
///
/// Anything that is not a well-formed marker (`[1:7]`, `[0:75]`,
/// `[Music]`) stays in the text. Text before the first marker, or a file
/// with no markers at all, becomes one untimed segment: still shown and
/// searchable, never highlighted or seekable.
class Transcript {
  Transcript(List<TranscriptSegment> segments)
    : segments = List.unmodifiable(segments),
      _timed = [
        for (var i = 0; i < segments.length; i++)
          if (segments[i].start != null) i,
      ];

  /// Splits [raw] into segments at its timestamp markers.
  factory Transcript.parse(String raw) {
    final segments = <TranscriptSegment>[];
    Duration? start;
    var textFrom = 0;

    void close(int textTo) {
      final text = raw
          .substring(textFrom, textTo)
          .replaceAll(_whitespace, ' ')
          .trim();
      if (text.isNotEmpty) {
        segments.add(TranscriptSegment(start: start, text: text));
      }
    }

    for (final marker in _marker.allMatches(raw)) {
      final at = _markerTime(marker);
      if (at == null) continue;
      close(marker.start);
      start = at;
      textFrom = marker.end;
    }
    close(raw.length);
    return Transcript(segments);
  }

  final List<TranscriptSegment> segments;

  /// Indices of the timed segments, in order.
  final List<int> _timed;

  /// Whether the transcript carries any timestamps — i.e. whether it can
  /// follow playback and seek.
  bool get isTimed => _timed.isNotEmpty;

  /// The segment being spoken at [position]: the last timed segment that has
  /// started. Null before the first marker or for an untimed transcript.
  int? segmentAt(Duration position) {
    var lo = 0;
    var hi = _timed.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (segments[_timed[mid]].start! <= position) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo == 0 ? null : _timed[lo - 1];
  }

  /// Every occurrence of [query], case- and diacritics-insensitive, in
  /// reading order. Whitespace in the query is collapsed the way segment
  /// text is, so pasted text still matches. Empty for a blank query.
  List<TranscriptMatch> search(String query) {
    final needle = _Folded.of(query.replaceAll(_whitespace, ' ').trim()).text;
    if (needle.isEmpty) return const [];
    final folded = _folded ??= [for (final s in segments) _Folded.of(s.text)];
    final matches = <TranscriptMatch>[];
    for (var i = 0; i < folded.length; i++) {
      final haystack = folded[i];
      var from = 0;
      while (true) {
        final at = haystack.text.indexOf(needle, from);
        if (at < 0) break;
        final end = at + needle.length;
        matches.add(
          TranscriptMatch(i, haystack.starts[at], haystack.ends[end - 1]),
        );
        from = end;
      }
    }
    return matches;
  }

  /// Folded segment text, built on the first search and kept for the rest.
  List<_Folded>? _folded;

  static final _marker = RegExp(r'\[(\d+):(\d+)(?::(\d+))?\]');
  static final _whitespace = RegExp(r'\s+');

  /// The time a marker stands for, or null when it is malformed: seconds
  /// (and, in `h:mm:ss`, minutes) must be two digits under 60.
  static Duration? _markerTime(RegExpMatch m) {
    final a = m.group(1)!;
    final b = m.group(2)!;
    final c = m.group(3);
    if (c == null) {
      if (b.length != 2) return null;
      final minutes = int.parse(a);
      final seconds = int.parse(b);
      if (seconds >= 60) return null;
      return Duration(minutes: minutes, seconds: seconds);
    }
    if (b.length != 2 || c.length != 2) return null;
    final hours = int.parse(a);
    final minutes = int.parse(b);
    final seconds = int.parse(c);
    if (minutes >= 60 || seconds >= 60) return null;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}

/// Text lower-cased with diacritics and typographic quotes folded away, plus
/// where each folded code unit came from in the original, so a hit in the
/// folded text maps back to the exact original range.
class _Folded {
  _Folded(this.text, this.starts, this.ends);

  factory _Folded.of(String source) {
    final out = StringBuffer();
    final starts = <int>[];
    final ends = <int>[];
    var at = 0;
    for (final rune in source.runes) {
      final width = rune > 0xFFFF ? 2 : 1;
      final folded = _fold(rune);
      for (var i = 0; i < folded.length; i++) {
        starts.add(at);
        ends.add(at + width);
      }
      out.write(folded);
      at += width;
    }
    return _Folded(out.toString(), starts, ends);
  }

  final String text;

  /// Original start / end offsets of each folded code unit.
  final List<int> starts;
  final List<int> ends;

  static String _fold(int rune) {
    // Combining marks (decomposed accents) carry no letter of their own.
    if (rune >= 0x0300 && rune <= 0x036F) return '';
    final lower = String.fromCharCode(rune).toLowerCase();
    if (lower.length == 1) {
      final base = _bases[lower.codeUnitAt(0)];
      if (base != null) return base;
    }
    return lower;
  }

  static final Map<int, String> _bases = {
    for (final MapEntry(key: base, value: variants) in const {
      'a': 'àáâãäåāăą',
      'ae': 'æ',
      'c': 'çćĉċč',
      'd': 'ďđð',
      'e': 'èéêëēĕėęě',
      'g': 'ĝğġģ',
      'h': 'ĥħ',
      'i': 'ìíîïĩīĭįı',
      'j': 'ĵ',
      'k': 'ķ',
      'l': 'ĺļľŀł',
      'n': 'ñńņňŉ',
      'o': 'òóôõöøōŏő',
      'oe': 'œ',
      'r': 'ŕŗř',
      's': 'śŝşšș',
      'ss': 'ß',
      't': 'ţťŧț',
      'u': 'ùúûüũūŭůűų',
      'w': 'ŵ',
      'y': 'ýÿŷ',
      'z': 'źżž',
      "'": '‘’ʼ′',
      '"': '“”″',
    }.entries)
      for (final unit in variants.codeUnits) unit: base,
  };
}
