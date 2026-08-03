import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Player scrubber — dark design-handoff (v3).
///
/// Paints a row of uniform, evenly-spaced bars. The played portion (up to the
/// exact `position / duration` fraction) is gold; the rest is muted, with a
/// full-height gold cursor marking the current position. Tap or drag anywhere
/// to seek. Time labels sit below — elapsed left, total right.
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

  /// Fraction (0.0–1.0) to display, accounting for a live drag.
  double get _fraction {
    if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0.0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _displayPosition {
    if (_dragFraction != null) {
      return Duration(
        milliseconds: (_dragFraction! * widget.duration.inMilliseconds).round(),
      );
    }
    return widget.position;
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  void _seekToFraction(double f) {
    widget.onSeek(Duration(
      milliseconds: (f * widget.duration.inMilliseconds).round(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final timeStyle = AppTypography.ui(
      size: 11.5,
      weight: FontWeight.w600,
      color: context.kc.muted,
    );

    const waveH = 40.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(builder: (_, constraints) {
          final trackWidth = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seekToFraction(
                (d.localPosition.dx / trackWidth).clamp(0.0, 1.0)),
            onHorizontalDragUpdate: (d) {
              setState(() {
                _dragFraction =
                    ((_dragFraction ?? _fraction) + d.delta.dx / trackWidth)
                        .clamp(0.0, 1.0);
              });
            },
            onHorizontalDragEnd: (_) {
              if (_dragFraction != null) _seekToFraction(_dragFraction!);
              setState(() => _dragFraction = null);
            },
            child: SizedBox(
              height: waveH,
              width: trackWidth,
              child: CustomPaint(
                painter: _WaveformPainter(
                  fraction: _fraction,
                  played: context.kc.accent,
                  unplayed: context.kc.muted.withValues(alpha: 0.35),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_displayPosition), style: timeStyle),
            Text(_fmt(widget.duration), style: timeStyle),
          ],
        ),
      ],
    );
  }
}

/// Uniform bar scrubber: equal-height rounded bars split at [fraction], with a
/// full-height gold cursor at the play head.
class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.fraction,
    required this.played,
    required this.unplayed,
  });

  final double fraction;
  final Color played;
  final Color unplayed;

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 3.0;
    final step = barW + gap;
    final count = (size.width / step).floor().clamp(1, 2000);
    final splitX = (fraction * size.width).clamp(0.0, size.width);
    final cy = size.height / 2;
    final barH = size.height * 0.55;

    final playedPaint = Paint()
      ..color = played
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    final unplayedPaint = Paint()
      ..color = unplayed
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final x = i * step + barW / 2;
      canvas.drawLine(
        Offset(x, cy - barH / 2),
        Offset(x, cy + barH / 2),
        x <= splitX ? playedPaint : unplayedPaint,
      );
    }

    // Full-height play head.
    final cursorX = splitX.clamp(barW / 2, size.width - barW / 2);
    canvas.drawLine(
      Offset(cursorX, cy - size.height / 2),
      Offset(cursorX, cy + size.height / 2),
      playedPaint,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.fraction != fraction ||
      old.played != played ||
      old.unplayed != unplayed;
}
