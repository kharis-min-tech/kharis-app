import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';


/// A 56-px-tall list row for a single sermon.
///
/// Shows an animated equalizer when [isPlaying] is true.
class SermonListItem extends StatefulWidget {
  const SermonListItem({
    super.key,
    required this.title,
    required this.speaker,
    required this.duration,
    required this.pubDate,
    this.artworkColor,
    this.isPlaying = false,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String speaker;
  final String duration;
  final DateTime pubDate;
  final int? artworkColor;
  final bool isPlaying;
  final VoidCallback? onTap;

  /// Optional trailing widget (e.g. drag handle).
  final Widget? trailing;

  @override
  State<SermonListItem> createState() => _SermonListItemState();
}

class _SermonListItemState extends State<SermonListItem>
    with TickerProviderStateMixin {
  late final List<AnimationController> _barControllers;
  late final List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();
    // Three equalizer bars with offset durations so they're out of phase.
    final durations = [350, 500, 420];
    _barControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: durations[i]),
      ),
    );
    _barAnimations = _barControllers.map((c) {
      return Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    _syncAnimation();
  }

  @override
  void didUpdateWidget(SermonListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isPlaying) {
      for (final c in _barControllers) {
        c.repeat(reverse: true);
      }
    } else {
      for (final c in _barControllers) {
        c.stop();
        c.animateTo(0.3, duration: const Duration(milliseconds: 200));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _barControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = sermonGradient(widget.artworkColor ?? 0);
    final dateStr =
        '${widget.pubDate.year}-${widget.pubDate.month.toString().padLeft(2, '0')}-${widget.pubDate.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            _Thumbnail(
              gradientColors: gradientColors,
              isPlaying: widget.isPlaying,
              barAnimations: _barAnimations,
            ),
            const SizedBox(width: 12),
            // ── Text block ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.mavenPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.speaker} · $dateStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textBody,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Duration ──────────────────────────────────────────────────
            Text(
              widget.duration,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.gradientColors,
    required this.isPlaying,
    required this.barAnimations,
  });

  final List<Color> gradientColors;
  final bool isPlaying;
  final List<Animation<double>> barAnimations;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: isPlaying ? _EqualizerBars(animations: barAnimations) : null,
    );
  }
}

class _EqualizerBars extends StatelessWidget {
  const _EqualizerBars({required this.animations});

  final List<Animation<double>> animations;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: animations[i],
              builder: (_, _) {
                return Container(
                  width: 4,
                  height: 20 * animations[i].value,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
