import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

import '../widgets/seek_bar.dart';
import '../widgets/player_controls.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen> {
  double _playbackSpeed = 1.0;

  static const _speedSteps = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  void _cycleSpeed() {
    final idx = _speedSteps.indexOf(_playbackSpeed);
    final next = _speedSteps[(idx + 1) % _speedSteps.length];
    setState(() => _playbackSpeed = next);
    ref.read(audioPlayerServiceProvider).setSpeed(next);
  }

  @override
  Widget build(BuildContext context) {
    final sermon = ref.watch(currentSermonProvider);
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred gradient background ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2A1A0A), // warm dark amber
                  AppColors.surfaceDark,
                ],
                stops: [0.0, 0.55],
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),

          // ── Content ──────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // App bar row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      Expanded(
                        child: Text(
                          'Now Playing',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // ── Artwork ────────────────────────────────────────────────────
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6B34FA), Color(0xFFFD7F20)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 4,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: sermon?.artworkUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            sermon!.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) =>
                                const _ArtworkPlaceholder(),
                          ),
                        )
                      : const _ArtworkPlaceholder(),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Track info ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    children: [
                      Text(
                        sermon?.title ?? 'No sermon loaded',
                        style: GoogleFonts.mavenPro(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        sermon?.speaker ?? '',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.orange,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // ── Seek bar ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: SeekBar(
                    position: position,
                    duration: duration,
                    onSeek: (d) => service.seek(d),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Controls ───────────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: PlayerControls(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Speed pill ─────────────────────────────────────────────────
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.surfaceSubtle, width: 1.5),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${_playbackSpeed % 1 == 0 ? _playbackSpeed.toInt() : _playbackSpeed}x',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── Bottom actions ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xxl,
                    right: AppSpacing.xxl,
                    bottom: AppSpacing.lg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BottomAction(
                        icon: Icons.notes_rounded,
                        label: 'Notes',
                        onTap: () {},
                      ),
                      _BottomAction(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: () {},
                      ),
                      _BottomAction(
                        icon: Icons.queue_music_rounded,
                        label: 'Playlist',
                        onTap: () {},
                      ),
                      _BottomAction(
                        icon: Icons.playlist_play_rounded,
                        label: 'Queue',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Artwork placeholder ────────────────────────────────────────────────────────

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.mic_none_rounded,
        color: Colors.white54,
        size: 64,
      ),
    );
  }
}

// ── Bottom action chip ─────────────────────────────────────────────────────────

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textBody, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}
