import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

import '../screens/full_player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermon = ref.watch(currentSermonProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    // Nothing loaded — render nothing
    if (sermon == null) return const SizedBox.shrink();

    final isPlaying = playerState?.playing ?? false;
    final progressFraction = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => const FullPlayerScreen(),
            fullscreenDialog: true,
          ),
        );
      },
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // ── Gold progress bar at top ─────────────────────────────────────
              LayoutBuilder(builder: (ctx, constraints) {
                return Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    height: 2,
                    width: progressFraction * constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: Radius.circular(
                          progressFraction >= 1.0 ? 12 : 0,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // ── Main row ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6B34FA), Color(0xFFFD7F20)],
                        ),
                      ),
                      child: sermon.artworkUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                sermon.artworkUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => const Icon(
                                  Icons.mic_none_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.mic_none_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                    ),

                    const SizedBox(width: AppSpacing.md),

                    // Title + speaker
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sermon.title,
                            style: GoogleFonts.mavenPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            sermon.speaker,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppColors.textBody,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Play / Pause
                    IconButton(
                      onPressed: () =>
                          isPlaying ? service.pause() : service.resume(),
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.orange,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
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
}
