import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

import 'media_player_screen.dart';
import '../widgets/player_actions.dart';
import '../widgets/player_controls.dart';
import '../widgets/seek_bar.dart';

/// Full-screen Now Playing — dark design-handoff (v3).
///
/// Rises over the current tab. Purple→ink ambient gradient. Top row is a
/// collapse chevron, the centred series label, and an overflow menu. A large
/// square artwork dominates, followed by the title + speaker·scripture line
/// with a like heart, an Audio/Video segmented toggle, the waveform scrubber,
/// transport controls, and the secondary action row (Notes / Playlist / Share).
class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermon = ref.watch(currentSermonProvider);
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    final series = (sermon?.series ?? sermon?.category ?? 'Now playing')
        .toUpperCase();
    final subtitle = _subtitle(sermon);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3A1D6E),
              Color(0xFF1A0F33),
              AppColors.ink,
            ],
            stops: [0.0, 0.44, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Row(
                  children: [
                    _IconTapTarget(
                      icon: Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        series,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          size: 10,
                          weight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: AppColors.darkMuted2,
                        ),
                      ),
                    ),
                    _IconTapTarget(
                      icon: Icons.more_horiz_rounded,
                      size: 22,
                      onTap: () => _showActionsSheet(context),
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ───────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Large square artwork.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.5),
                                  blurRadius: 60,
                                  offset: const Offset(0, 28),
                                  spreadRadius: -20,
                                ),
                              ],
                            ),
                            child: ArtworkImage(
                              url: sermon?.artworkUrl,
                              gradientIndex: sermon?.artworkColor ?? 0,
                              radius: AppRadius.card,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title + scripture line + like heart.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sermon?.title ?? 'No sermon loaded',
                                  style: AppTypography.display(
                                    size: 22,
                                    weight: FontWeight.w700,
                                    height: 1.08,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle,
                                    style: AppTypography.ui(
                                      size: 13.5,
                                      color: AppColors.darkMuted2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const _LikeButton(),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Audio / Video segmented toggle.
                      _MediaToggle(sermon: sermon),

                      const SizedBox(height: 22),

                      // Waveform scrubber.
                      SeekBar(
                        position: position,
                        duration: duration,
                        onSeek: (d) => service.seek(d),
                      ),

                      const SizedBox(height: 18),

                      // Transport controls.
                      const PlayerControls(),

                      const SizedBox(height: 26),

                      // Secondary actions.
                      Container(
                        padding: const EdgeInsets.only(top: 18),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x17FFFFFF)),
                          ),
                        ),
                        child: const PlayerActions(),
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

  static String _subtitle(Sermon? sermon) {
    if (sermon == null) return '';
    final speaker = sermon.speaker;
    final extra = sermon.category ?? sermon.series;
    if (extra != null && extra.isNotEmpty && extra != speaker) {
      return '$speaker · $extra';
    }
    return speaker;
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [PlayerActions()],
          ),
        );
      },
    );
  }
}

// ── Like heart (local UI toggle) ──────────────────────────────────────────────

class _LikeButton extends StatefulWidget {
  const _LikeButton();

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _liked ? 'Unlike' : 'Like',
      child: GestureDetector(
        onTap: () => setState(() => _liked = !_liked),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 2, left: 6),
          child: Icon(
            _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: AppColors.gold,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ── Audio / Video segmented toggle ────────────────────────────────────────────

class _MediaToggle extends StatelessWidget {
  const _MediaToggle({required this.sermon});

  final Sermon? sermon;

  @override
  Widget build(BuildContext context) {
    final hasVideo = sermon?.videoId != null;
    return Row(
      children: [
        const _ToggleChip(label: 'Audio', active: true),
        const SizedBox(width: 9),
        _ToggleChip(
          label: 'Video',
          active: false,
          enabled: hasVideo,
          onTap: hasVideo
              ? () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => MediaPlayerScreen(sermon: sermon!),
                    ),
                  )
              : null,
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = active ? AppColors.gold : AppColors.darkSurface2;
    final Color fg = active
        ? AppColors.goldInk
        : (enabled ? AppColors.darkMuted : AppColors.darkMuted.withValues(alpha: 0.4));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Top-bar icon tap target ───────────────────────────────────────────────────

class _IconTapTarget extends StatelessWidget {
  const _IconTapTarget({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
