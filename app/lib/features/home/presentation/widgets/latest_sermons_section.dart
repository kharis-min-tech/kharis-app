import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

import '../../../../shared/providers/audio_provider.dart';
import '../../../../shared/providers/sermon_provider.dart';
import 'sermon_card.dart';

// Gradient palette indexed by Sermon.artworkColor (0–9).
const _kGradients = [
  [Color(0xFF1A0A3B), Color(0xFF6B34FA)],
  [Color(0xFF1A2A0A), Color(0xFF22C55E)],
  [Color(0xFF3B1A0A), Color(0xFFFD7F20)],
  [Color(0xFF0A1A3B), Color(0xFF3B82F6)],
  [Color(0xFF2A0A1A), Color(0xFF800654)],
  [Color(0xFF0A3B2A), Color(0xFF14B8A6)],
  [Color(0xFF3B2A0A), Color(0xFFF59E0B)],
  [Color(0xFF0A2A3B), Color(0xFF0EA5E9)],
  [Color(0xFF2A3B0A), Color(0xFF84CC16)],
  [Color(0xFF1A0A2A), Color(0xFFEC4899)],
];

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
                  final palette = _kGradients[
                      (sermon.artworkColor ?? index) % _kGradients.length];
                  return SermonCard(
                    title: sermon.title,
                    speaker: sermon.speaker,
                    gradientColors: [palette[0], palette[1]],
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
