import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Brand gradients cycled across news cards (used when no imageUrl).
const _kNewsGradients = [
  [Color(0xFF8B0A50), Color(0xFFC0305A)],
  [Color(0xFF1A0A3B), Color(0xFF6B34FA)],
  [Color(0xFF2A0A1A), Color(0xFFDC3F9E)],
];

String _age(DateTime published) {
  final diff = DateTime.now().difference(published);
  if (diff.inDays >= 60) return '${diff.inDays ~/ 30} months ago';
  if (diff.inDays >= 30) return '1 month ago';
  if (diff.inDays >= 14) return '${diff.inDays ~/ 7} weeks ago';
  if (diff.inDays >= 7) return '1 week ago';
  if (diff.inDays >= 1) return '${diff.inDays} days ago';
  return 'Today';
}

class NewsSection extends ConsumerWidget {
  const NewsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsProvider);
    final items = newsAsync.valueOrNull ?? const <NewsItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'News & Updates',
          style: GoogleFonts.mavenPro(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => _NewsCard(
              item: items[index],
              gradientColors:
                  _kNewsGradients[index % _kNewsGradients.length],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.gradientColors});

  final NewsItem item;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          // Content at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.mavenPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Kharis Church',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _age(item.publishedAt),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.type,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
