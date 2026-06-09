import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/seek_bar.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermon = ref.watch(currentSermonProvider);
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration =
        ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8E8EC), Color(0xFFBFC2C8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: thumbnail + title/speaker + close + add ─────────
                Row(
                  children: [
                    // Artwork thumbnail
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.purple, Color(0xFF9B5DE5)],
                        ),
                      ),
                      child: sermon?.artworkUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                sermon!.artworkUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Title + speaker
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sermon?.title ?? 'No sermon loaded',
                            style: GoogleFonts.mavenPro(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sermon?.speaker ?? '',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: const Color(0xFF6B6B6B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF1A1A1A),
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    // Add button
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF1A1A1A),
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Seek bar ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SeekBar(
                    position: position,
                    duration: duration,
                    onSeek: (d) => service.seek(d),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Controls ─────────────────────────────────────────────────
                const PlayerControls(),

                const Spacer(),

                // ── Bottom row: bluetooth | share + queue ────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.bluetooth,
                        color: Color(0xFF6B6B6B),
                        size: 24,
                      ),
                      Row(
                        children: const [
                          Icon(
                            Icons.ios_share,
                            color: Color(0xFF6B6B6B),
                            size: 24,
                          ),
                          SizedBox(width: 20),
                          Icon(
                            Icons.queue_music_rounded,
                            color: Color(0xFF6B6B6B),
                            size: 24,
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
      ),
    );
  }
}
