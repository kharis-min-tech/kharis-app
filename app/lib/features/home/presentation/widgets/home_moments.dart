import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/moments_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'home_branch_news.dart';

/// How many of the newest shorts Home lists.
const int kHomeMomentsCount = 10;

/// "0:52".
String _length(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// "Moments": the church's newest shorts as tall tiles; a tap plays one in
/// the app's video player. Renders nothing while there are none, and when
/// they could not be loaded.
class HomeMoments extends ConsumerWidget {
  const HomeMoments({super.key, this.padding = EdgeInsets.zero});

  /// Around the whole section; the carousel itself runs edge to edge.
  final EdgeInsetsGeometry padding;

  /// The message the library holds for this short.
  static Sermon _sermon(Moment moment) => Sermon(
    id: 'yt_${moment.videoId}',
    title: moment.title,
    speaker: 'Kharis Church',
    audioUrl: '',
    videoId: moment.videoId,
    artworkUrl: moment.thumbnailUrl,
    duration: moment.duration,
    publishedAt: moment.publishedAt,
    source: 'youtube',
  );

  /// Plays [moment]; Next and Previous walk the other [shown] shorts.
  void _play(
    BuildContext context,
    WidgetRef ref,
    Moment moment,
    List<Moment> shown,
  ) => unawaited(
    startPlayback(
      context,
      ref,
      _sermon(moment),
      queue: [for (final m in shown) _sermon(m)],
      mode: MediaMode.video,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(momentsProvider);
    final moments = async.valueOrNull;
    if (moments == null) {
      if (async.hasError) return const SizedBox.shrink();
    } else if (moments.isEmpty) {
      return const SizedBox.shrink();
    }
    final shown = moments?.take(kHomeMomentsCount).toList();

    final k = context.k;
    final width = homeCarouselItemWidth(context, gap: KSpace.lg, perView: 2);

    return Padding(
      key: const Key('home-moments'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Moments',
                    style: KharisText.section.copyWith(color: k.text),
                  ),
                ),
                const SizedBox(height: KSpace.xxs),
                Text(
                  'Our latest shorts. Tap to watch, swipe for more.',
                  style: KharisText.meta.copyWith(color: k.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.xl),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: shown == null
                  ? [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: KSpace.lg),
                        KSkeleton(
                          key: i == 0 ? const Key('home-moments-loading') : null,
                          width: width,
                          height: width / KMediaAspect.short.ratio,
                        ),
                      ],
                    ]
                  : [
                      for (final (i, moment) in shown.indexed) ...[
                        if (i > 0) const SizedBox(width: KSpace.lg),
                        SizedBox(
                          width: width,
                          child: KMediaTile(
                            key: Key('home-moment-${moment.videoId}'),
                            title: moment.title,
                            image: CachedNetworkImageProvider(
                              moment.thumbnailUrl,
                            ),
                            duration: moment.duration == null
                                ? null
                                : _length(moment.duration!),
                            aspect: KMediaAspect.short,
                            onTap: () => _play(context, ref, moment, shown),
                          ),
                        ),
                      ],
                    ],
            ),
          ),
        ],
      ),
    );
  }
}
