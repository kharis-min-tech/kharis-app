import 'package:kharis_app/core/utils/html_entities.dart';

/// A reviewed dub aligned to the original sermon MP3, including its silences.
class SermonLanguageTrack {
  const SermonLanguageTrack({
    required this.language,
    required this.label,
    required this.audioUrl,
    required this.subtitlesUrl,
  });

  final String language;
  final String label;
  final String audioUrl;
  final String subtitlesUrl;

  static List<SermonLanguageTrack> fromManifest(
    Object? value, {
    required String sermonId,
    required String sourceAudioUrl,
  }) {
    if (value is! Map ||
        value['schemaVersion'] != 1 ||
        value['sermonId'] != sermonId ||
        value['sourceAudioUrl'] != sourceAudioUrl ||
        value['timeline'] != 'audio' ||
        value['tracks'] is! List) {
      throw const FormatException(
        'This translation belongs to another recording.',
      );
    }
    final seen = <String>{};
    return [
      for (final t in value['tracks'] as List)
        if (t is Map &&
            t['reviewed'] == true &&
            t['language'] is String &&
            RegExp(
              r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$',
            ).hasMatch(t['language'] as String) &&
            t['language'] != 'en' &&
            t['label'] is String &&
            (t['label'] as String).trim().isNotEmpty &&
            _https(t['audioUrl']) &&
            _https(t['subtitlesUrl']) &&
            seen.add(t['language'] as String))
          SermonLanguageTrack(
            language: t['language'] as String,
            label: (t['label'] as String).trim(),
            audioUrl: t['audioUrl'] as String,
            subtitlesUrl: t['subtitlesUrl'] as String,
          ),
    ];
  }
}

bool _https(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

class SermonCaption {
  const SermonCaption(this.start, this.end, this.text);
  final Duration start;
  final Duration end;
  final String text;

  bool contains(Duration position) => position >= start && position < end;
}

/// Accepts WebVTT cue identifiers, settings, CRLF and multiline captions.
List<SermonCaption> parseSermonCaptions(String vtt) {
  if (!vtt.replaceFirst('\uFEFF', '').startsWith('WEBVTT')) {
    throw const FormatException('Expected WebVTT subtitles.');
  }
  final result = <SermonCaption>[];
  final timing = RegExp(r'^(\S+)\s+-->\s+(\S+)');
  for (final block in vtt.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
    final lines = block.split('\n');
    if (lines.first.startsWith('NOTE') ||
        lines.first == 'STYLE' ||
        lines.first == 'REGION') {
      continue;
    }
    final i = lines.indexWhere((line) => timing.hasMatch(line));
    if (i < 0) continue;
    final match = timing.firstMatch(lines[i])!;
    final start = _time(match[1]!);
    final end = _time(match[2]!);
    if (start == null || end == null || end <= start) continue;
    final text = decodeHtmlEntities(
      lines.skip(i + 1).join('\n').replaceAll(RegExp(r'<[^>]*>'), ''),
    ).trim();
    if (text.isNotEmpty) result.add(SermonCaption(start, end, text));
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

Duration? _time(String text) {
  if (!RegExp(r'^(\d{2,}:)?\d{2}:\d{2}\.\d{3}$').hasMatch(text)) return null;
  final p = text.split(':');
  final seconds = double.parse(p.last);
  final minutes = int.parse(p[p.length - 2]);
  if (seconds >= 60 || minutes >= 60) return null;
  final hours = p.length == 3 ? int.parse(p.first) : 0;
  return Duration(
    milliseconds: ((hours * 3600 + minutes * 60 + seconds) * 1000).round(),
  );
}
