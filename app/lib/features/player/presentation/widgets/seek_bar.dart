import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_typography.dart';

/// Spotify-style seek bar.
///
/// Track is 4 px tall and rounded. The active fill is AppColors.heading
/// (near-white). The inactive portion is white at 25% alpha. A 14-px circular
/// thumb appears only while dragging. Time labels sit below: elapsed on the
/// left, negative-remaining on the right, both in AppColors.textMuted.
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragFraction;
  bool _isDragging = false;

  // Fraction (0.0 to 1.0) to display, accounting for live drag.
  double get _fraction {
    if (_dragFraction != null) return _dragFraction!;
    final ms = widget.duration.inMilliseconds;
    if (ms <= 0) return 0.0;
    return (widget.position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  // Position to show in the left label (drag-aware).
  Duration get _displayPosition {
    if (_dragFraction != null) {
      return Duration(
        milliseconds:
            (_dragFraction! * widget.duration.inMilliseconds).round(),
      );
    }
    return widget.position;
  }

  // Remaining time for the right label.
  Duration get _remaining {
    final r = widget.duration - _displayPosition;
    return r.isNegative ? Duration.zero : r;
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final timeStyle = AppTypography.labelMd.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
      letterSpacing: 0,
    );

    const trackH = 4.0;
    const knobSize = 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Track + thumb
        LayoutBuilder(builder: (_, constraints) {
          final trackWidth = constraints.maxWidth;
          final fillWidth = (_fraction * trackWidth).clamp(0.0, trackWidth);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final f = (d.localPosition.dx / trackWidth).clamp(0.0, 1.0);
              widget.onSeek(Duration(
                milliseconds: (f * widget.duration.inMilliseconds).round(),
              ));
            },
            onHorizontalDragStart: (_) {
              setState(() => _isDragging = true);
            },
            onHorizontalDragUpdate: (d) {
              setState(() {
                _dragFraction =
                    ((_dragFraction ?? _fraction) + d.delta.dx / trackWidth)
                        .clamp(0.0, 1.0);
              });
            },
            onHorizontalDragEnd: (_) {
              if (_dragFraction != null) {
                widget.onSeek(Duration(
                  milliseconds:
                      (_dragFraction! * widget.duration.inMilliseconds)
                          .round(),
                ));
              }
              setState(() {
                _dragFraction = null;
                _isDragging = false;
              });
            },
            child: SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Inactive track
                  Container(
                    height: trackH,
                    width: trackWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(trackH / 2),
                    ),
                  ),
                  // Active fill
                  Container(
                    height: trackH,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: AppColors.heading,
                      borderRadius: BorderRadius.circular(trackH / 2),
                    ),
                  ),
                  // Thumb, only visible while dragging
                  if (_isDragging)
                    Positioned(
                      left: (fillWidth - knobSize / 2)
                          .clamp(0.0, trackWidth - knobSize),
                      child: Container(
                        width: knobSize,
                        height: knobSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.heading,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 6),

        // Time labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_displayPosition), style: timeStyle),
            Text('-${_fmt(_remaining)}', style: timeStyle),
          ],
        ),
      ],
    );
  }
}
