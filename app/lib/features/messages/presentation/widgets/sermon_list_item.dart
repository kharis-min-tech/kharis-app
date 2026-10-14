import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// "28 min left", "1 h 5 min left", "Under 1 min left".
String timeLeftLabel(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil();
  if (remaining.inSeconds < 60) return 'Under 1 min left';
  if (minutes < 60) return '$minutes min left';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h left' : '$h h $m min left';
}

/// Spec-matching 56px sermon list row for the Messages tab.
///
/// Shows gradient art (play icon when idle, animated equalizer when playing),
/// title, speaker/category, date/duration meta with the member's listening
/// progress ("28 min left" and a bar, or "Finished"), and a 3-dot button.
class SermonListItem extends StatefulWidget {
  const SermonListItem({
    super.key,
    required this.title,
    required this.speaker,
    this.category,
    this.durationLabel = '',
    this.dateLabel = '',
    this.artworkColor,
    this.artworkUrl,
    this.listIndex = 0,
    this.isPlaying = false,
    this.onTap,
    this.onMoreTap,
    this.listening = const NotStarted(),
  });

  final String title;
  final String speaker;
  final String? category;
  final String durationLabel;
  final String dateLabel;
  final int? artworkColor;
  final String? artworkUrl;
  final int listIndex;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  /// Where the member is with this message; see [ListeningProgress].
  final ListeningProgress listening;

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
    _barControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 380 + i * 110),
      ),
    );
    _barAnimations = List.generate(
      3,
      (i) => Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _barControllers[i], curve: Curves.easeInOut),
      ),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(SermonListItem old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying) _syncAnimation();
  }

  void _syncAnimation() {
    for (final c in _barControllers) {
      if (widget.isPlaying) {
        c.repeat(reverse: true);
      } else {
        c.stop();
        c.value = 0.35;
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
    final cat = widget.category ?? '';
    final speakerLine = cat.isNotEmpty
        ? '${widget.speaker} · $cat'
        : widget.speaker;
    final listening = widget.listening;
    final metaLine = [
      widget.dateLabel,
      switch (listening) {
        InProgress(:final remaining?) => timeLeftLabel(remaining),
        _ => widget.durationLabel,
      },
    ].where((s) => s.isNotEmpty).join(' · ');
    final fraction = switch (listening) {
      InProgress(:final fraction?) => fraction.clamp(0.0, 1.0),
      _ => null,
    };
    final finished = listening is Finished;

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Gradient art (56x56, radius 11) ───────────────────────────────
            SizedBox(
              width: 56,
              height: 56,
              child: ArtworkImage(
                url: widget.artworkUrl,
                gradientIndex: widget.artworkColor ?? widget.listIndex,
                radius: 11,
                scrim: widget.isPlaying,
                overlay: widget.isPlaying
                    ? _EqualizerBars(animations: _barAnimations)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // ── Text block ────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ui(
                      size: 15,
                      weight: FontWeight.w600,
                      color: context.kc.onBg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    speakerLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ui(
                      size: 12.5,
                      color: context.kc.muted,
                    ),
                  ),
                  if (metaLine.isNotEmpty || finished) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            finished
                                ? [
                                    metaLine,
                                    'Finished',
                                  ].where((s) => s.isNotEmpty).join(' · ')
                                : metaLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.ui(
                              size: 11,
                              color: context.kc.muted,
                            ),
                          ),
                        ),
                        if (finished) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: context.kc.accent,
                            semanticLabel: 'Finished',
                          ),
                        ],
                        if (fraction != null) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: LinearProgressIndicator(
                                key: const Key('listening-progress'),
                                value: fraction,
                                minHeight: 3,
                                backgroundColor: context.kc.surfaceAlt,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.kc.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 3),
            // ── 3-dot button (34px circle in a 44px hit area) ─────────────────
            Semantics(
              button: true,
              label: 'More options',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: widget.onMoreTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.kc.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: context.kc.muted,
                      size: 18,
                    ),
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

// ── Animated equalizer bars ────────────────────────────────────────────────────

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
              builder: (_, _) => Container(
                width: 4,
                height: 20 * animations[i].value,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
