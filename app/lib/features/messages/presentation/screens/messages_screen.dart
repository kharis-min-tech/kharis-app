import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/sermon.dart';
import '../../../../shared/providers/audio_provider.dart';
import '../../../../shared/providers/sermon_provider.dart';

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

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonsAsync = ref.watch(sermonsProvider);
    final categories = ref.watch(categoryLabelsProvider);
    final selectedIndex = ref.watch(selectedCategoryIndexProvider);
    final filteredSermons = ref.watch(filteredSermonsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'Messages',
                style: GoogleFonts.mavenPro(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // ── Category filter chips ────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final selected = index == selectedIndex;
                  return GestureDetector(
                    onTap: () => ref
                        .read(selectedCategoryIndexProvider.notifier)
                        .state = index,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.orange
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        categories[index],
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Content area ─────────────────────────────────────────────
            Expanded(
              child: sermonsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.orange,
                  ),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Failed to load sermons',
                        style: GoogleFonts.dmSans(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(sermonsProvider),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: AppColors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (_) => filteredSermons.isEmpty
                    ? Center(
                        child: Text(
                          'No sermons found',
                          style: GoogleFonts.dmSans(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: filteredSermons.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => _SermonTile(
                          sermon: filteredSermons[index],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SermonTile extends ConsumerWidget {
  const _SermonTile({required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = _kGradients[
        (sermon.artworkColor ?? 0) % _kGradients.length];

    return GestureDetector(
      onTap: () =>
          ref.read(audioPlayerServiceProvider).play(sermon),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // ── Artwork thumbnail ──────────────────────────────────────
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette[0], palette[1]],
                ),
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // ── Meta ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sermon.title,
                    style: GoogleFonts.mavenPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    sermon.speaker,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (sermon.duration != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      sermon.formattedDuration,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.orange,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
