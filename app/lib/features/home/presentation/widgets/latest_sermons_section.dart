import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../shared/models/sermon.dart';

import '../../../../shared/providers/audio_provider.dart';
import '../../../../shared/providers/sermon_provider.dart';

// Figma Group 32 card colours — solid purple row, dark inner play square.
const _kCardBg = Color(0xFF3B1278);
const _kPlayBg = Color(0xFF1A0640);
const _kSubtitleColor = Color(0xFFB8B0C8);

class LatestSermonsSection extends ConsumerWidget {
  const LatestSermonsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonsAsync = ref.watch(sermonsProvider);
    final audioService = ref.read(audioPlayerServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              'Continue Listening',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/messages'),
              child: Text(
                'See all',
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

        // Cards
        sermonsAsync.when(
          loading: () => const _LoadingCards(),
          error: (_, _) => const SizedBox.shrink(),
          data: (sermons) {
            final items = sermons.take(4).toList();
            return Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _SermonRow(
                    sermon: items[i],
                    onPlay: () => audioService.play(items[i]),
                  ),
                  if (i < items.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SermonRow extends StatelessWidget {
  const _SermonRow({required this.sermon, required this.onPlay});

  final Sermon sermon;
  final VoidCallback onPlay;

  Future<void> _handleTap() async {
    if (sermon.isYouTubeVideo && sermon.youtubeUrl != null) {
      await launchUrlString(sermon.youtubeUrl!);
    } else {
      onPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationStr = sermon.duration != null
        ? '${sermon.duration!.inMinutes} min'
        : null;
    final subtitle = durationStr != null
        ? '${sermon.speaker} · $durationStr'
        : sermon.speaker;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Play icon square — matches Figma dark inner container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kPlayBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sermon.title,
                    style: GoogleFonts.mavenPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: _kSubtitleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          height: 72,
          decoration: BoxDecoration(
            color: _kCardBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
