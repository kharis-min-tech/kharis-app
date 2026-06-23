import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

import '../widgets/player_actions.dart';
import '../widgets/player_controls.dart';
import '../widgets/seek_bar.dart';

/// Spotify-style Now Playing screen.
///
/// The ambient background is a vertical gradient derived from
/// sermonGradient(sermon.artworkColor): the palette's primary colour at the
/// top bleeding into AppColors.canvas at the bottom (65% stop). The full
/// artwork square is the dominant element. Playback controls sit below,
/// and secondary actions (Notes) appear at the bottom.
class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermon = ref.watch(currentSermonProvider);
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    // Derive ambient colour from the sermon's artwork gradient palette.
    final gradColors = sermonGradient(sermon?.artworkColor ?? 0);
    final ambientTop = gradColors[0];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ambientTop,       // artwork-derived colour at top
              AppColors.canvas, // deepest black at ~65%
            ],
            stops: const [0.0, 0.65],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    // Collapse chevron
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                    // "NOW PLAYING" centred label
                    Expanded(
                      child: Text(
                        'NOW PLAYING',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),

                    // 3-dot: shows secondary actions in a bottom sheet
                    GestureDetector(
                      onTap: () => _showActionsSheet(context),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Large artwork: ~82% of screen width, radius 14, coloured shadow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: ambientTop.withValues(alpha: 0.55),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ArtworkImage(
                      url: sermon?.artworkUrl,
                      gradientIndex: sermon?.artworkColor ?? 0,
                      radius: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title and speaker, left-aligned
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sermon?.title ?? 'No sermon loaded',
                      style: AppTypography.headlineLgMobile.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sermon?.speaker ?? '',
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Seek bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SeekBar(
                  position: position,
                  duration: duration,
                  onSeek: (d) => service.seek(d),
                ),
              ),

              const SizedBox(height: 24),

              // Playback controls (shuffle / -15s / play-pause / +15s / repeat)
              const PlayerControls(),

              const Spacer(),

              // Secondary actions row at the bottom
              const PlayerActions(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomPad),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [PlayerActions()],
          ),
        );
      },
    );
  }
}
