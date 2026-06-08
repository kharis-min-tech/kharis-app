import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

import '../../../../shared/providers/audio_provider.dart';
import '../../../../shared/providers/sermon_provider.dart';
import 'sermon_card.dart';
import '../../../../core/utils/artwork_gradient.dart';


class LatestSermonsSection extends ConsumerWidget {
  const LatestSermonsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonsAsync = ref.watch(sermonsProvider);
    final audioService = ref.read(audioPlayerServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ───────────────────────────────────────────────────
        Row(
          children: [
            Text(
              'Latest Sermons',
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
                'See All',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Horizontal scroll ────────────────────────────────────────────────
        sermonsAsync.when(
          loading: () => const SizedBox(
            height: 210,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
          ),
          error: (_, _) => const SizedBox(
            height: 210,
            child: Center(
              child: Text(
                'Could not load sermons',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
          data: (sermons) {
            final latest = sermons.take(5).toList();
            return SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: latest.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final sermon = latest[index];
                  final palette = sermonGradient(sermon.artworkColor ?? index);
                  return SermonCard(
                    title: sermon.title,
                    speaker: sermon.speaker,
                    gradientColors: palette,
                    onTap: () => audioService.play(sermon),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
