import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';

// Brand gradient pairs cycled across announcement cards.
const _kCardGradients = [
  [Color(0xFF6B1E8B), Color(0xFF2A0A52)],
  [Color(0xFF1A0A3B), Color(0xFF6B34FA)],
  [Color(0xFF2A0A1A), Color(0xFFDC3F9E)],
  [Color(0xFF0A2A1A), Color(0xFF059669)],
  [Color(0xFF3B1A0A), Color(0xFFF59E0B)],
];

/// "Announcements" horizontal carousel wired to newsProvider.
class AnnouncementsCarousel extends ConsumerWidget {
  const AnnouncementsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userBranch = ref.watch(currentBranchProvider).valueOrNull;
    // Scoped server-side by getAnnouncements?branch= — no client-side filter.
    final newsAsync = ref.watch(newsProvider(userBranch));
    final items = newsAsync.valueOrNull ?? const <NewsItem>[];

    if (items.isEmpty) {
      return SizedBox(
        height: 148,
        child: Center(
          child: Text(
            'No announcements',
            style: TextStyle(
              color: context.kc.muted,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 148,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 12 : 0),
            child: _AnnouncementCard(
              item: item,
              gradientColors: _kCardGradients[i % _kCardGradients.length],
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.item,
    required this.gradientColors,
  });

  final NewsItem item;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // An announcement is a message, not a dated occurrence — it opens the
      // announcement feed, never the events calendar.
      onTap: () => context.go('/notifications'),
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Admin-set image over the gradient, under the scrim.
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // Bottom scrim
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .65),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tag pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.type.toUpperCase(),
                            style: AppTypography.labelMd.copyWith(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.9,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      item.title,
                      style: AppTypography.titleMd.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.15,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.body != null && item.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body!,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: .82),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
