import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';

import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';
import 'package:kharis_app/shared/models/sermon.dart';

class LatestMessageCard extends ConsumerWidget {
  const LatestMessageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videosProvider);
    final video = videos.isNotEmpty ? videos.first : null;

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
        // Video card — taps into the in-app YouTube player
        if (video == null)
          _buildNullSkeleton()
        else if (DateTime.now().weekday == DateTime.sunday)
          _buildSundayHero(context, video)
        else
          GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (context) => MediaPlayerScreen(sermon: video),
                ),
              );
            },
            child: _buildVideoCard(
              title: video.title,
              speaker: video.speaker,
              gradientColors: sermonGradient(video.artworkColor ?? 0),
              artworkUrl: video.artworkUrl,
            ),
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

  Widget _buildNullSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Skeleton(width: double.infinity, height: double.infinity, radius: 0),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonLine(width: 200),
      ],
    );
  }

  Widget _buildSundayHero(BuildContext context, Sermon video) {
    final gradientColors = sermonGradient(video.artworkColor ?? 0);
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (context) => MediaPlayerScreen(sermon: video),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: artwork or gradient
              if (video.artworkUrl != null)
                Image.network(
                  video.artworkUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _gradientBg(gradientColors),
                )
              else
                _gradientBg(gradientColors),
              // Bottom gradient scrim: transparent -> 85% black
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.85)],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              // Scrim content
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SUNDAY overline pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'SUNDAY',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Title + WATCH NOW pill row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            video.title,
                            style: GoogleFonts.mavenPro(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'WATCH NOW',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
