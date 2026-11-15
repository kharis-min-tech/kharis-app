import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// A message's artwork at row size, or null for the placeholder.
ImageProvider? messageArtwork(Sermon sermon, {int size = 3 * 56}) {
  final url = sermon.artworkUrl?.trim();
  if (url == null || url.isEmpty) return null;
  return ResizeImage(
    CachedNetworkImageProvider(url),
    width: size,
    height: size,
  );
}

/// "Pastor David Antwi · 12 Oct 2026"; either part alone when the other is
/// missing, null when both are.
String? messageMeta(Sermon sermon) {
  final parts = [
    if (sermon.speaker.trim().isNotEmpty) sermon.speaker.trim(),
    if (sermon.publishedAt != null)
      DateFormat('d MMM y').format(sermon.publishedAt!),
  ];
  return parts.isEmpty ? null : parts.join(' \u00b7 ');
}

/// "48 min", or null when the length is unknown.
String? messageLength(Duration? duration) {
  if (duration == null || duration <= Duration.zero) return null;
  final minutes = (duration.inSeconds / 60).round();
  return '${minutes < 1 ? 1 : minutes} min';
}

/// "28 min left", "1 h 5 min left", "Under 1 min left".
String timeLeftLabel(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil();
  if (remaining.inSeconds < 60) return 'Under 1 min left';
  if (minutes < 60) return '$minutes min left';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h left' : '$h h $m min left';
}

/// The first passage the message is preached from, for its badge.
String? messagePassage(Sermon sermon) {
  for (final p in sermon.passages) {
    if (p.trim().isNotEmpty) return p.trim();
  }
  return null;
}

/// The Bible books (USFM codes) [sermon]'s passages name, each once.
Set<String> messageBooks(Sermon sermon, BibleIndex canon) => {
  for (final passage in sermon.passages)
    for (final at in parseReadingReferences(passage, canon)) at.usfm,
};

/// One Bible book that messages are preached from.
typedef MessageBook = ({String usfm, String name, List<Sermon> sermons});

/// Books named by the library's passages, in canonical order, each with its
/// messages newest first. Empty while no message carries a passage.
final messageBooksProvider = Provider<List<MessageBook>>((ref) {
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  final canon = BibleIndex.bundled();
  final byBook = <String, List<Sermon>>{};
  for (final s in sermons) {
    if (s.passages.isEmpty) continue;
    for (final usfm in messageBooks(s, canon)) {
      (byBook[usfm] ??= []).add(s);
    }
  }
  return [
    for (final b in kCanonBooks)
      if (byBook[b.usfm] case final list?)
        (usfm: b.usfm, name: b.name, sermons: newestFirst(list)),
  ];
});

/// [sermons] sorted newest first; undated messages last.
List<Sermon> newestFirst(Iterable<Sermon> sermons) => sermons.toList()
  ..sort(
    (a, b) =>
        (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)),
  );

/// The messages of one series in preaching order, part 1 first.
List<Sermon> seriesParts(Iterable<Sermon> sermons, String series) =>
    newestFirst(sermons.where((s) => s.series == series)).reversed.toList();

/// One message as a row of a list: tapping plays it with [queue] next; a
/// long press (or the screen-reader action) offers add to a collection and
/// notes.
class MessageRow extends ConsumerWidget {
  const MessageRow({
    super.key,
    required this.sermon,
    required this.queue,
    this.trailingLabel,
    this.trailing,
  });

  final Sermon sermon;

  /// What plays after it: the list the row is in.
  final List<Sermon> queue;

  /// Overrides the length or time left, for example with a file size.
  final String? trailingLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listening = ref.watch(listeningProgressProvider(sermon));
    final fraction = listening is InProgress ? listening.fraction : null;
    final left = listening is InProgress ? listening.remaining : null;
    return KMessageRow(
      title: sermon.title,
      meta: messageMeta(sermon),
      badge: messagePassage(sermon),
      trailingLabel:
          trailingLabel ??
          switch (listening) {
            Finished() => 'Finished',
            _ when left != null => timeLeftLabel(left),
            _ => messageLength(sermon.duration),
          },
      trailing: trailing,
      image: messageArtwork(sermon),
      progress: fraction,
      progressLabel: fraction == null
          ? null
          : '${(fraction * 100).round()}% listened',
      onTap: () => unawaited(startPlayback(context, ref, sermon, queue: queue)),
      onMore: () => unawaited(
        showAddToPlaylistSheet(
          context,
          sermonId: sermon.id,
          sermonTitle: sermon.title,
          onOpenNotes: () => SermonNotesSheet.show(context, sermon),
        ),
      ),
      moreLabel: 'Add to a collection',
    );
  }
}

/// A pushed list of messages: a book's, a theme's or a series' parts.
class MessageListScreen extends StatelessWidget {
  const MessageListScreen({
    super.key,
    required this.title,
    required this.sermons,
  });

  final String title;
  final List<Sermon> sermons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: KScreenHeader(title: title)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                KSpace.gutter,
                KSpace.lg,
                KSpace.gutter,
                KSize.contentBottomPad + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: KSliverListGroup(
                itemCount: sermons.length,
                itemBuilder: (context, i) => MessageRow(
                  key: ValueKey(sermons[i].id),
                  sermon: sermons[i],
                  queue: sermons,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
