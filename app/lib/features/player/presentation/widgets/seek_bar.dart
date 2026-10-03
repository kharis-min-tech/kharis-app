import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Player timeline scrubber.
///
/// A thin rounded track: the played portion is filled solid up to the exact
/// `position / duration` fraction, the rest is a faint rail, and a round thumb
/// marks the play head. Tap or drag anywhere to seek; the thumb grows while
/// dragging. Time labels sit below — elapsed on the left, time remaining
/// (`-m:ss`) on the right.
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
  /// Touch target height; the painted track is much thinner and centred.
  static const _hitHeight = 28.0;

  double? _dragFraction;

  /// Fraction (0.0–1.0) to display, accounting for a live drag.
  double get _fraction {
    if (_dragFraction != null) return _dragFraction!;
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0.0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _displayPosition {
    if (_dragFraction != null) return _durationAt(_dragFraction!);
    return widget.position;
  }

  Duration _durationAt(double f) =>
      Duration(milliseconds: (f * widget.duration.inMilliseconds).round());

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static double _fractionAt(double dx, double width) =>
      width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.kc;
    final timeStyle = AppTypography.ui(
      size: 11.5,
      weight: FontWeight.w600,
      color: colors.muted,
    );

    final elapsed = _displayPosition;
    final remaining = widget.duration > elapsed
        ? widget.duration - elapsed
        : Duration.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (_, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => widget.onSeek(
                _durationAt(_fractionAt(d.localPosition.dx, width)),
              ),
              onHorizontalDragStart: (d) => setState(() {
                _dragFraction = _fractionAt(d.localPosition.dx, width);
              }),
              onHorizontalDragUpdate: (d) => setState(() {
                _dragFraction = _fractionAt(d.localPosition.dx, width);
              }),
              onHorizontalDragEnd: (_) {
                final f = _dragFraction;
                if (f != null) widget.onSeek(_durationAt(f));
                setState(() => _dragFraction = null);
              },
              onHorizontalDragCancel: () =>
                  setState(() => _dragFraction = null),
              child: SizedBox(
                height: _hitHeight,
                width: width,
                child: CustomPaint(
                  painter: _TimelinePainter(
                    fraction: _fraction,
                    dragging: _dragFraction != null,
                    played: colors.onBg,
                    rail: colors.onBg.withValues(alpha: 0.22),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(elapsed), style: timeStyle),
            Text('-${_fmt(remaining)}', style: timeStyle),
          ],
        ),
      ],
    );
  }
}

/// Thin rounded rail, solid fill up to [fraction], round thumb at the head.
class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.fraction,
    required this.dragging,
    required this.played,
    required this.rail,
  });

  final double fraction;
  final bool dragging;
  final Color played;
  final Color rail;

  static const _trackHeight = 4.0;
  static const _thumbRadius = 6.0;
  static const _thumbRadiusDragging = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final top = cy - _trackHeight / 2;
    const radius = Radius.circular(_trackHeight / 2);
    final headX = fraction * size.width;

    canvas.drawRRect(
      RRect.fromLTRBR(0, top, size.width, top + _trackHeight, radius),
      Paint()..color = rail,
    );

    final fill = Paint()..color = played;
    if (headX > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, top, headX, top + _trackHeight, radius),
        fill,
      );
    }

    canvas.drawCircle(
      Offset(headX, cy),
      dragging ? _thumbRadiusDragging : _thumbRadius,
      fill,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.fraction != fraction ||
      old.dragging != dragging ||
      old.played != played ||
      old.rail != rail;
}
