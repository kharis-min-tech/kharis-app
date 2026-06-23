import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_spacing.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import '../widgets/sermon_list_item.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  // Key used to scroll the "All Messages" header into view when a topic is tapped.
  final _listHeaderKey = GlobalKey();

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

    // Playback state from audio_provider only (no collision with sermon_provider).
    final currentSermon = ref.watch(currentSermonProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;

    // Active sort.
    final sort = ref.watch(sermonSortProvider);

    // Active category filter: drives the highlighted topic card, the dynamic
    // "All Messages" -> category title, and the removable filter chip below.
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isFiltered = selectedCategory != 'All';

    // Build category -> count map from the unfiltered list.
    final allSermons = sermonsAsync.valueOrNull ?? const [];
    final Map<String, int> categoryCounts = {};
    for (final s in allSermons) {
      if (s.category != null) {
        categoryCounts[s.category!] = (categoryCounts[s.category!] ?? 0) + 1;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── 1. Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: AppTypography.headlineLg.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                        letterSpacing: -0.18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sermons & teachings · streamed from Kharis',
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── 2a. "Find encouragement" label ───────────────────────────────
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
                        color: AppColors.heading,
                        letterSpacing: -0.18,
                      ),
                    ),
                    const Spacer(),
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
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 2b. Topic playlist carousel (150x150 cards) ──────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                // 150px card + 8px gap + ~34px count label
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
                                // Tap to filter; tap the active topic to clear.
                                ref
                                        .read(selectedCategoryProvider.notifier)
                                        .state =
                                    selectedCategory == cat ? 'All' : cat;
                                _scrollToList();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── 3. "All Messages" row + Newest/Oldest sort pills ─────────────
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
                              color: AppColors.heading,
                              letterSpacing: -0.18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _SortPill(
                          label: 'Newest',
                          active: sort == SermonSort.newest,
                          onTap: () => ref
                              .read(sermonSortProvider.notifier)
                              .state = SermonSort.newest,
                        ),
                        const SizedBox(width: 8),
                        _SortPill(
                          label: 'Oldest',
                          active: sort == SermonSort.oldest,
                          onTap: () => ref
                              .read(sermonSortProvider.notifier)
                              .state = SermonSort.oldest,
                        ),
                      ],
                    ),
                    if (isFiltered) ...[
                      const SizedBox(height: 12),
                      _FilterChip(
                        label: selectedCategory,
                        count: sermons.length,
                        onClear: () => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = 'All',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── 4. Sermon list (unlimited, no batch labels) ──────────────────
            if (sermons.isEmpty && sermonsAsync.isLoading)
              // Loading skeletons while data is in flight
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
                    onTap: () {
                      // Audio only: start playback; mini player handles navigation.
                      ref.read(audioPlayerServiceProvider).play(sermon);
                    },
                  );
                },
              ),

            // ── Bottom pad: clears mini player + tab bar ─────────────────────
            const SliverPadding(padding: EdgeInsets.only(bottom: 150)),
          ],
        ),
      ),
    );
  }
}

// ── Topic playlist card (150x150) ─────────────────────────────────────────────

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
                  ? Border.all(color: AppColors.secondary, width: 2.5)
                  : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Bottom scrim
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
                // Category title above the play button
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
                // Play button (gold check when this topic is the active filter)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: active ? AppColors.secondary : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Icon(
                      active ? Icons.check_rounded : Icons.play_arrow_rounded,
                      color:
                          active ? AppColors.onSecondary : AppColors.surfaceDark,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // "{n} messages" count label, or the active-filter state in gold.
        Text(
          active ? 'Filtering · $count' : '$count messages',
          style: AppTypography.bodySm.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.secondary : const Color(0xFFCFC8D4),
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
          color: AppColors.secondary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label · $count',
              style: AppTypography.labelMd.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort pill (gold active, glass inactive) ────────────────────────────────────

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
          color: active
              ? AppColors.secondary
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: active
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.onSecondary : AppColors.onSurface,
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
          // Art placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(width: 12),
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 3-dot placeholder
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
    );
  }
}
