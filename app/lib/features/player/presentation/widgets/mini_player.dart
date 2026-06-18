import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import '../screens/media_player_screen.dart';

/// Persistent mini player bar (56px) above tab bar.
/// Shows current playing sermon with artwork, title, and play/pause.
/// Gold 2px progress line at top. Tap to expand.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(audioPlayerServiceProvider);
    final sermon = service.currentSermon;

    if (sermon == null) return const SizedBox.shrink();

    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final isPlaying = playerState?.playing ?? false;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;

    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Semantics(
      button: true,
      label: 'Open player for ${sermon.title}',
      child: PressEffect(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (context) => MediaPlayerScreen(sermon: sermon),
          ),
        );
      },
      child: Container(
        height: 58, // 56px + 2px progress line
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: Colors.white10, width: 0.5),
          ),
        ),
        child: Column(
          children: [
            // Gold progress line
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
            // Mini player content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Artwork thumbnail
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: AppColors.surfaceSubtle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: sermon.artworkUrl != null
                          ? Image.network(
                              sermon.artworkUrl!,
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              Icons.music_note,
                              color: Colors.white54,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Title and speaker
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sermon.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            sermon.speaker,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Play/Pause button
                    Semantics(
                      button: true,
                      label: isPlaying ? 'Pause' : 'Play',
                      excludeSemantics: true,
                      child: IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            key: ValueKey<bool>(isPlaying),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            service.pause();
                          } else {
                            service.resume();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
