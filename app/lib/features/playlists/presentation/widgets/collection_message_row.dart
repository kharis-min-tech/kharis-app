import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/collection_labels.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// One message in a collection or in Favourites: artwork, title, and a meta
/// line with the speaker, the length and where the member is with it
/// ("Playing", "28 min left", "Played"). Tapping the row plays it; the
/// trailing button removes it.
class CollectionMessageRow extends ConsumerWidget {
  const CollectionMessageRow({
    super.key,
    required this.sermon,
    required this.onTap,
    required this.onRemove,
    required this.removeLabel,
  });

  final Sermon sermon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// What the remove button announces, for example
  /// "Remove Walking in Faith from Favourites".
  final String removeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing =
        ref.watch(currentSermonProvider)?.id == sermon.id &&
        (ref.watch(playerStateProvider).valueOrNull?.playing ?? false);
    final length = sermon.duration;
    final meta = [
      if (playing) 'Playing',
      if (sermon.speaker.isNotEmpty) sermon.speaker,
      if (length != null) listeningLengthLabel(length),
      if (!playing)
        ...switch (ref.watch(listeningProgressProvider(sermon))) {
          InProgress(:final remaining?) => [
            '${listeningLengthLabel(remaining)} left',
          ],
          Finished() => const ['Played'],
          _ => const <String>[],
        },
    ].join(' · ');
    final artwork = usableMediaUrl(sermon.artworkUrl);

    return KListRow(
      title: sermon.title,
      meta: meta.isEmpty ? null : meta,
      leading: KThumbnail(
        image: artwork == null
            ? null
            : ResizeImage(
                CachedNetworkImageProvider(artwork),
                width: (KSize.thumb * MediaQuery.devicePixelRatioOf(context))
                    .round(),
              ),
      ),
      trailing: KIconButton(
        icon: KIcons.close,
        label: removeLabel,
        onPressed: onRemove,
      ),
      onTap: onTap,
    );
  }
}
