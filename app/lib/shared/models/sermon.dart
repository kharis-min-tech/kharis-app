import 'package:flutter/foundation.dart';

@immutable
class Sermon {
  const Sermon({
    required this.id,
    required this.title,
    required this.speaker,
    required this.audioUrl,
    this.artworkUrl,
    this.duration,
    this.publishedAt,
    this.series,
    this.description,
    this.artworkColor,
    this.category,
    this.videoId,
    this.source,
    this.isFeatured = false,
  });

  /// Returns true if this is a YouTube video (has videoId, no audioUrl)
  bool get isYouTubeVideo => videoId != null && videoId!.isNotEmpty;

  /// YouTube video URL for opening in browser/player
  String? get youtubeUrl => isYouTubeVideo ? 'https://www.youtube.com/watch?v=$videoId' : null;

  final String id;
  final String title;
  final String speaker;
  final String audioUrl;
  final String? artworkUrl;
  final Duration? duration;
  final DateTime? publishedAt;
  final String? series;

  // ── Media-library additions ────────────────────────────────────────────────
  final String? description;

  /// Index into the artwork gradient palette (0–9).
  final int? artworkColor;

  /// Category label (e.g. "Faith", "Prayer", "Messages").
  final String? category;

  /// YouTube video ID (for videos synced from YouTube)
  final String? videoId;

  /// Content source: 'youtube', 'soundcloud', etc.
  final String? source;

  /// Whether this sermon is featured on the Messages home.
  final bool isFeatured;

  // ── Derived ───────────────────────────────────────────────────────────────

  String get formattedDuration {
    final d = duration;
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Sermon copyWith({
    String? id,
    String? title,
    String? speaker,
    String? audioUrl,
    String? artworkUrl,
    Duration? duration,
    DateTime? publishedAt,
    String? series,
    String? description,
    int? artworkColor,
    String? category,
    String? videoId,
    String? source,
    bool? isFeatured,
  }) {
    return Sermon(
      id: id ?? this.id,
      title: title ?? this.title,
      speaker: speaker ?? this.speaker,
      audioUrl: audioUrl ?? this.audioUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      duration: duration ?? this.duration,
      publishedAt: publishedAt ?? this.publishedAt,
      series: series ?? this.series,
      description: description ?? this.description,
      artworkColor: artworkColor ?? this.artworkColor,
      category: category ?? this.category,
      videoId: videoId ?? this.videoId,
      source: source ?? this.source,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sermon &&
        other.id == id &&
        other.title == title &&
        other.speaker == speaker &&
        other.audioUrl == audioUrl &&
        other.artworkUrl == artworkUrl &&
        other.duration == duration &&
        other.publishedAt == publishedAt &&
        other.series == series &&
        other.description == description &&
        other.artworkColor == artworkColor &&
        other.category == category &&
        other.isFeatured == isFeatured;
  }

  @override
  int get hashCode => Object.hash(
   id,
   title,
   speaker,
   audioUrl,
   artworkUrl,
   duration,
   publishedAt,
   series,
   description,
   artworkColor,
   category,
   isFeatured,
 );

  @override
  String toString() =>
      'Sermon(id: $id, title: $title, speaker: $speaker, series: $series, category: $category)';
}
