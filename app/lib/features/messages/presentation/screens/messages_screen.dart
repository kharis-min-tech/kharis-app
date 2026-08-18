import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import '../widgets/sermon_list_item.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _listHeaderKey = GlobalKey();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scrollToList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _listHeaderKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Categories: skip 'All' for the topic carousel.
    final categories = ref
        .watch(categoryLabelsProvider)
        .where((c) => c != 'All')
        .toList();

    // Filtered + sorted sermon list.
    final sermons = ref.watch(librarySermonsProvider);

    // Raw async for loading detection and per-category counts.
    final sermonsAsync = ref.watch(sermonsProvider);

    // Playback state.
    final currentSermon = ref.watch(currentSermonProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;

    // Active sort.
    final sort = ref.watch(sermonSortProvider);

    // Active category filter.
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isFiltered = selectedCategory != 'All';

    // Featured + Message of the Day + recently played.
    final featured = ref.watch(featuredSermonsProvider);
    final motd = ref.watch(motdSermonProvider);
    final recentlyPlayed = ref.watch(recentlyPlayedProvider);

    // Search.
    final searchQuery = ref.watch(sermonSearchProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final isSearching = searchQuery.trim().isNotEmpty;

    // Build category -> count map from the unfiltered list.
    final allSermons = sermonsAsync.valueOrNull ?? const [];
    final Map<String, int> categoryCounts = {};
    for (final s in allSermons) {
      if (s.category != null) {
        categoryCounts[s.category!] = (categoryCounts[s.category!] ?? 0) + 1;
      }
    }

    final library = ref.watch(sermonLibraryProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          // Infinite scroll: near the bottom, pull the next archive page.
          // loadMore() self-guards (in-flight / archive exhausted), so firing
          // on every scroll tick is safe. Search renders a separate list, and
          // its short scroll extent would otherwise page in the background.
          onNotification: (n) {
            if (!isSearching &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
              ref.read(sermonLibraryProvider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
          slivers: [
            // ── 1. Header + Search ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: AppTypography.display(
                        size: 30,
                        weight: FontWeight.w700,
                        height: 1.0,
                        color: context.kc.onBg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sermons & teachings · streamed from Kharis',
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 13,
                        color: context.kc.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          ref.read(sermonSearchProvider.notifier).state = v,
                      onCleared: () {
                        _searchCtrl.clear();
                        ref.read(sermonSearchProvider.notifier).state = '';
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Search results (when searching) ──────────────────────────────
            if (isSearching) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '${searchResults.length} result${searchResults.length == 1 ? '' : 's'} for "$searchQuery"',
                    style: AppTypography.bodySm.copyWith(
                      color: context.kc.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (searchResults.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        'No sermons found',
                        style: TextStyle(color: context.kc.muted),
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final sermon = searchResults[index];
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
                      category: sermon.category,
                      durationLabel: sermon.formattedDuration,
                      dateLabel: dateLabel,
                      artworkColor: sermon.artworkColor,
                      artworkUrl: sermon.artworkUrl,
                      listIndex: index,
                      isPlaying: isPlaying,
                      onTap: () => startPlayback(ref, sermon),
                      onMoreTap: () => showAddToPlaylistSheet(
                        context,
                        sermonId: sermon.id,
                        sermonTitle: sermon.title,
                      ),
                    );
                  },
                ),
            ]
            // ── Normal browse mode ───────────────────────────────────────────
            else ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── 2. Featured hero carousel + Message of the Day ───────────
              if (featured.isNotEmpty)
                SliverToBoxAdapter(
                  child: _FeaturedCarousel(
                    sermons: featured,
                    currentSermonId: currentSermon?.id,
                    isPlaying: playerState?.playing ?? false,
                    onPlay: (sermon) => startPlayback(ref, sermon),
                  ),
                ),
              if (motd != null) ...[
                if (featured.isNotEmpty)
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: _MessageOfTheDayCard(
                    sermon: motd,
                    isPlaying:
                        currentSermon?.id == motd.id &&
                        (playerState?.playing ?? false),
                    onPlay: () => startPlayback(ref, motd),
                  ),
                ),
              ],

              // ── 3. Recently played ───────────────────────────────────────
              if (recentlyPlayed.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Text(
                      'Recently played',
                      style: AppTypography.bodyLg.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.kc.onBg,
                        letterSpacing: -0.18,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.marginMobile,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: recentlyPlayed.length,
                      itemBuilder: (context, index) {
                        final sermon = recentlyPlayed[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < recentlyPlayed.length - 1 ? 12 : 0,
                          ),
                          child: _RecentlyPlayedCard(
                            sermon: sermon,
                            isPlaying:
                                currentSermon?.id == sermon.id &&
                                (playerState?.playing ?? false),
                            onTap: () => startPlayback(ref, sermon),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // ── 4. "Find encouragement" + topic carousel ─────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Find encouragement',
                        style: AppTypography.bodyLg.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.kc.onBg,
                          letterSpacing: -0.18,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        // Root-navigator route: overlays the shell with its
                        // own back affordance instead of replacing this tab's
                        // content with an inescapable branch push.
                        onTap: () => context.push('/playlists'),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'Playlists',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.kc.accentInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          ref.read(selectedCategoryProvider.notifier).state =
                              'All';
                          _scrollToList();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'See all',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.kc.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 196,
                  child: categories.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.marginMobile,
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final count = categoryCounts[cat] ?? 0;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < categories.length - 1 ? 12 : 0,
                              ),
                              child: _TopicCard(
                                category: cat,
                                count: count,
                                gradientIndex: index,
                                active: selectedCategory == cat,
                                onTap: () {
                                  ref
                                      .read(selectedCategoryProvider.notifier)
                                      .state = selectedCategory == cat
                                      ? 'All'
                                      : cat;
                                  _scrollToList();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),

              // ── 5. "All Messages" + sort pills ───────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: Padding(
                  key: _listHeaderKey,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              isFiltered ? selectedCategory : 'All Messages',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyLg.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: context.kc.onBg,
                                letterSpacing: -0.18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SortPill(
                            label: 'Newest',
                            active: sort == SermonSort.newest,
                            onTap: () =>
                                ref.read(sermonSortProvider.notifier).state =
                                    SermonSort.newest,
                          ),
                          const SizedBox(width: 8),
                          _SortPill(
                            label: 'Oldest',
                            active: sort == SermonSort.oldest,
                            onTap: () =>
                                ref.read(sermonSortProvider.notifier).state =
                                    SermonSort.oldest,
                          ),
                        ],
                      ),
                      if (isFiltered) ...[
                        const SizedBox(height: 12),
                        _FilterChip(
                          label: selectedCategory,
                          count: sermons.length,
                          onClear: () =>
                              ref
                                      .read(selectedCategoryProvider.notifier)
                                      .state =
                                  'All',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── 6. Sermon list ───────────────────────────────────────────
              if (sermons.isEmpty && sermonsAsync.isLoading)
                SliverList.builder(
                  itemCount: 6,
                  itemBuilder: (_, _) => const _SermonRowSkeleton(),
                )
              else
                SliverList.builder(
                  itemCount: sermons.length,
                  itemBuilder: (context, index) {
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
                      category: sermon.category,
                      durationLabel: sermon.formattedDuration,
                      dateLabel: dateLabel,
                      artworkColor: sermon.artworkColor,
                      artworkUrl: sermon.artworkUrl,
                      listIndex: index,
                      isPlaying: isPlaying,
                      onTap: () => startPlayback(ref, sermon),
                      onMoreTap: () => showAddToPlaylistSheet(
                        context,
                        sermonId: sermon.id,
                        sermonTitle: sermon.title,
                      ),
                    );
                  },
                ),
              // ── 7. Archive paging footer ─────────────────────────────────
              if (library.isLoadingMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: context.kc.muted,
                        ),
                      ),
                    ),
                  ),
                )
              else if (library.loaded && !library.hasMore && sermons.length > 20)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'You\'ve reached the beginning \u2022 ${library.sermons.length} sermons',
                        style: AppTypography.bodySm
                            .copyWith(color: context.kc.muted),
                      ),
                    ),
                  ),
                ),
            ],

            // ── Bottom pad ──────────────────────────────────────────────────
            const SliverPadding(padding: EdgeInsets.only(bottom: 150)),
          ],
          ),
        ),
      ),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: context.kc.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: AppTypography.bodyLg.copyWith(color: context.kc.onBg),
            cursorColor: context.kc.accentInk,
            decoration: InputDecoration(
              hintText: 'Search sermons, speakers, topics...',
              hintStyle: AppTypography.bodySm.copyWith(color: context.kc.muted),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: context.kc.muted,
              ),
              suffixIcon: hasText
                  ? GestureDetector(
                      onTap: onCleared,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: context.kc.muted,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(color: context.kc.accentInk, width: 1.5),
              ),
              focusedErrorBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: context.kc.surfaceAlt,
            ),
          ),
        );
      },
    );
  }
}

// ── Featured hero carousel ─────────────────────────────────────────────────────

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({
    required this.sermons,
    required this.currentSermonId,
    required this.isPlaying,
    required this.onPlay,
  });

  final List<Sermon> sermons;
  final String? currentSermonId;
  final bool isPlaying;
  final void Function(Sermon) onPlay;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  late final PageController _pageCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sermons.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.sermons.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final sermon = widget.sermons[index];
              final isCurrent = widget.currentSermonId == sermon.id;
              final isPlaying = isCurrent && widget.isPlaying;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _FeaturedCard(
                  sermon: sermon,
                  isPlaying: isPlaying,
                  isActive: index == _currentPage,
                  onPlay: () => widget.onPlay(sermon),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.sermons.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _currentPage ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? context.kc.accent
                    : context.kc.outline,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Featured card ──────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.sermon,
    required this.isPlaying,
    required this.isActive,
    required this.onPlay,
  });

  final Sermon sermon;
  final bool isPlaying;
  final bool isActive;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final gradColors = sermonGradient(sermon.artworkColor ?? 0);
    return PressEffect(
      onTap: onPlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: gradColors[1].withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Sermon artwork thumbnail as the card background.
            ArtworkImage(
              url: sermon.artworkUrl,
              gradientIndex: sermon.artworkColor ?? 0,
              radius: AppRadius.lg,
            ),
            // Bottom scrim for text legibility
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.lg),
                    bottomRight: Radius.circular(AppRadius.lg),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE6000000)],
                  ),
                ),
              ),
            ),
            // Featured badge
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.kc.accent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.equalizer_rounded : Icons.star_rounded,
                      size: 12,
                      color: context.kc.onAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPlaying ? 'NOW PLAYING' : 'FEATURED',
                      style: AppTypography.labelMd.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: context.kc.onAccent,
                        letterSpacing: 0.08,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Play button
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            // Title + speaker
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sermon.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLg.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        sermon.speaker,
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      if (sermon.category != null) ...[
                        Text(
                          ' · ${sermon.category}',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
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

// ── Message of the Day card ────────────────────────────────────────────────────

class _MessageOfTheDayCard extends StatelessWidget {
  const _MessageOfTheDayCard({
    required this.sermon,
    required this.isPlaying,
    required this.onPlay,
  });

  final Sermon sermon;
  final bool isPlaying;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: PressEffect(
        onTap: onPlay,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.kc.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.kc.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ArtworkImage(
                  url: sermon.artworkUrl,
                  gradientIndex: sermon.artworkColor ?? 0,
                  radius: AppRadius.md,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.wb_sunny_rounded,
                          size: 12,
                          color: context.kc.accentInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'MESSAGE OF THE DAY',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: context.kc.accentInk,
                            letterSpacing: 0.08,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sermon.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLg.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.kc.onBg,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sermon.speaker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 12,
                        color: context.kc.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.kc.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(
                  isPlaying
                      ? Icons.equalizer_rounded
                      : Icons.play_arrow_rounded,
                  color: context.kc.onAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recently played card ───────────────────────────────────────────────────────

class _RecentlyPlayedCard extends StatelessWidget {
  const _RecentlyPlayedCard({
    required this.sermon,
    required this.isPlaying,
    required this.onTap,
  });

  final Sermon sermon;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressEffect(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: ArtworkImage(
                    url: sermon.artworkUrl,
                    gradientIndex: sermon.artworkColor ?? 0,
                    radius: AppRadius.md,
                    overlay: isPlaying
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.equalizer_rounded,
                                color: AppColors.secondary,
                                size: 28,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.kc.accent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: context.kc.onAccent,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sermon.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.kc.onBg,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Topic playlist card (150x150) ─────────────────────────────────────────────

/// Ink for the circular chip that floats over a topic card's artwork gradient.
/// Invariant on purpose: the gradient beneath it does not follow the theme, so
/// neither does the chip.
const Color _onArtworkChipInk = Color(0xFF0B0A10);

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.category,
    required this.count,
    required this.gradientIndex,
    required this.active,
    required this.onTap,
  });

  final String category;
  final int count;
  final int gradientIndex;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = sermonGradient(gradientIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              border: active
                  ? Border.all(color: context.kc.accent, width: 2.5)
                  : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: context.kc.accent.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 90,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xBB000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 44,
                  left: 10,
                  right: 10,
                  child: Text(
                    category,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLg.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: active ? context.kc.accent : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Icon(
                      active ? Icons.check_rounded : Icons.play_arrow_rounded,
                      color: active ? context.kc.onAccent : _onArtworkChipInk,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          active ? 'Filtering · $count' : '$count messages',
          style: AppTypography.bodySm.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? context.kc.accentInk : context.kc.muted,
          ),
        ),
      ],
    );
  }
}

// ── Active filter chip (tap to clear back to All) ─────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.onClear,
  });

  final String label;
  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClear,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
        decoration: BoxDecoration(
          color: context.kc.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: context.kc.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label · $count',
              style: AppTypography.labelMd.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.kc.accentInk,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.close_rounded, size: 16, color: context.kc.accentInk),
          ],
        ),
      ),
    );
  }
}

// ── Sort pill (gold active, muted surface inactive) ───────────────────────────

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? context.kc.accent : context.kc.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? context.kc.onAccent : context.kc.muted,
          ),
        ),
      ),
    );
  }
}

// ── Skeleton row (loading state) ──────────────────────────────────────────────

class _SermonRowSkeleton extends StatelessWidget {
  const _SermonRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.kc.surfaceAlt,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: context.kc.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: context.kc.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.kc.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
    );
  }
}
