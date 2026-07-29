import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// Playlists library (dark) — series & collections shown as artwork cards.
///
/// Tapping a card opens [_PlaylistDetailScreen], an ordered sermon list that
/// reuses the Messages [SermonListItem] visual spec. Playback + navigation to
/// the player go through the existing audio/sermon providers unchanged.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({
    super.key,
    this.playlistName = 'ACTS SERIES',
  });

  /// Retained for API stability; if supplied it seeds the initially-highlighted
  /// collection, otherwise the full library is shown.
  final String playlistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playlists',
                      style: AppTypography.headlineLg.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                        letterSpacing: -0.18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Series & collections · curated from Kharis',
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Collection cards ──────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.76,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _CollectionCard(
                    collection: _kCollections[index],
                  ),
                  childCount: _kCollections.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Collection model + data ───────────────────────────────────────────────────

class _Collection {
  const _Collection({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.keyword,
    required this.gradientIndex,
    this.asset,
  });

  final String title;
  final String subtitle;
  final int count;

  /// Matched (case-insensitive) against a sermon's category / series / title.
  final String keyword;
  final int gradientIndex;
  final String? asset;
}

const List<_Collection> _kCollections = [
  _Collection(
    title: 'Book of Acts',
    subtitle:
        'Going through the book of Acts, line upon line, precept upon precept.',
    count: 86,
    keyword: 'acts',
    gradientIndex: 0,
    asset: AppAssets.seriesActs,
  ),
  _Collection(
    title: 'June Fasting 2026',
    subtitle: 'Corporate fast — daily devotionals to seek His face.',
    count: 12,
    keyword: 'fasting',
    gradientIndex: 3,
    asset: AppAssets.seriesFasting,
  ),
  _Collection(
    title: 'Sunday Mornings',
    subtitle: 'Weekend worship messages from across the Kharis family.',
    count: 24,
    keyword: 'sunday',
    gradientIndex: 6,
  ),
  _Collection(
    title: 'Prayer & Fasting',
    subtitle: 'Teachings on the discipline of prayer and consecration.',
    count: 9,
    keyword: 'prayer',
    gradientIndex: 8,
  ),
];

// ── Collection card ─────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final _Collection collection;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PlaylistDetailScreen(collection: collection),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork
            AspectRatio(
              aspectRatio: 1.12,
              child: _CollectionArt(collection: collection),
            ),
            // Title + count
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${collection.count} messages',
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 11.5,
                      color: AppColors.darkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionArt extends StatelessWidget {
  const _CollectionArt({required this.collection});

  final _Collection collection;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient base (falls through if the asset is missing).
        ArtworkImage(
          url: null,
          gradientIndex: collection.gradientIndex,
          radius: 0,
        ),
        if (collection.asset != null)
          Image.asset(
            collection.asset!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        // Bottom scrim for legibility of the play badge.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x552B2140)],
            ),
          ),
        ),
        // Gold play badge.
        Positioned(
          right: 10,
          bottom: 10,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.goldInk,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Playlist detail ──────────────────────────────────────────────────────────

class _PlaylistDetailScreen extends ConsumerWidget {
  const _PlaylistDetailScreen({required this.collection});

  final _Collection collection;

  /// Audio-only sermons matching the collection keyword; falls back to the
  /// first few audio sermons so the list is never empty.
  List<Sermon> _resolve(List<Sermon> all) {
    final audio = all
        .where((s) => !s.isYouTubeVideo && s.audioUrl.isNotEmpty)
        .toList();
    final key = collection.keyword.toLowerCase();
    final matched = audio.where((s) {
      final cat = (s.category ?? '').toLowerCase();
      final series = (s.series ?? '').toLowerCase();
      final title = s.title.toLowerCase();
      return cat.contains(key) || series.contains(key) || title.contains(key);
    }).toList();
    return matched.isNotEmpty ? matched : audio.take(8).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final sermonsAsync = ref.watch(sermonsProvider);
    final currentSermon = ref.watch(currentSermonProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;

    final sermons = sermonsAsync.maybeWhen(
      data: _resolve,
      orElse: () => const <Sermon>[],
    );

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Top bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.heading,
                        size: 30,
                      ),
                    ),
                    Text(
                      'Playlists',
                      style: AppTypography.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.darkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Artwork + meta ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                            boxShadow: AppShadows.miniPlayer,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _CollectionArt(collection: collection),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      collection.title,
                      style: AppTypography.display(
                        size: 26,
                        weight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      collection.subtitle,
                      style: AppTypography.serif(
                        size: 14,
                        italic: true,
                        height: 1.5,
                        color: AppColors.darkMuted2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Playlist · ${collection.count} messages',
                      style: AppTypography.labelMd.copyWith(
                        fontSize: 12,
                        color: AppColors.darkMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Play all (gold CTA).
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: sermons.isEmpty
                            ? null
                            : () => audioService.play(sermons.first),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.goldInk,
                          disabledBackgroundColor:
                              AppColors.gold.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: Text(
                          'Play all',
                          style: AppTypography.ui(
                            size: 15,
                            weight: FontWeight.w700,
                            color: AppColors.goldInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.darkSurface, height: 1),
                  ],
                ),
              ),
            ),

            // ── Loading ───────────────────────────────────────────────────
            if (sermonsAsync.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),

            // ── Ordered sermon list (Messages row spec) ───────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sermon = sermons[index];
                  final isCurrent = currentSermon?.id == sermon.id;
                  final isPlaying =
                      isCurrent && (playerState?.playing ?? false);
                  final dateLabel = sermon.publishedAt != null
                      ? DateFormat('MMM yyyy').format(sermon.publishedAt!)
                      : '';
                  return SermonListItem(
                    key: ValueKey(sermon.id),
                    title: sermon.title,
                    speaker: sermon.speaker,
                    category: sermon.series ?? sermon.category,
                    durationLabel: sermon.formattedDuration,
                    dateLabel: dateLabel,
                    artworkColor: sermon.artworkColor,
                    artworkUrl: sermon.artworkUrl,
                    listIndex: index,
                    isPlaying: isPlaying,
                    onTap: () => audioService.play(sermon),
                  );
                },
                childCount: sermons.length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}
