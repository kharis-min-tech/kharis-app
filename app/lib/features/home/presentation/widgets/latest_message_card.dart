import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import '../../../../shared/providers/sermon_provider.dart';
import '../../../../core/utils/artwork_gradient.dart';

class LatestMessageCard extends ConsumerWidget {
  const LatestMessageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonsAsync = ref.watch(sermonsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Latest Message',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Text(
                'See More',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Video card
        sermonsAsync.when(
          loading: () => _buildVideoCard(
            title: 'Future-Proofing the Church',
            speaker: 'Kharis Church',
            gradientColors: const [Color(0xFF2A1A0A), Color(0xFF6B34FA)],
          ),
          error: (_, _) => _buildVideoCard(
            title: 'Latest Sermon',
            speaker: 'Kharis Church',
            gradientColors: const [Color(0xFF2A1A0A), Color(0xFF6B34FA)],
          ),
          data: (sermons) {
            final sermon = sermons.isNotEmpty ? sermons.first : null;
            return _buildVideoCard(
              title: sermon?.title ?? 'Future-Proofing the Church',
              speaker: sermon?.speaker ?? 'Kharis Church',
              gradientColors: sermonGradient(sermon?.artworkColor ?? 0),
              artworkUrl: sermon?.artworkUrl,
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoCard({
    required String title,
    required String speaker,
    required List<Color> gradientColors,
    String? artworkUrl,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: artwork or gradient
            if (artworkUrl != null)
              Image.network(
                artworkUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _gradientBg(gradientColors),
              )
            else
              _gradientBg(gradientColors),
            // Dark overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
            // Top-left: channel avatar + info (YouTube style)
            Positioned(
              top: 12,
              left: 12,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF333333),
                    ),
                    child: const Icon(
                      Icons.church,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.length > 20
                            ? '${title.substring(0, 20)}...'
                            : title,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        speaker,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Center: big red YouTube play button
            const Center(
              child: _YouTubePlayButton(),
            ),
            // Bottom footer bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black.withValues(alpha: 0.6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.smart_display,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Watch on YouTube',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBg(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}

class _YouTubePlayButton extends StatelessWidget {
  const _YouTubePlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000), // YouTube red
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}
