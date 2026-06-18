import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

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

  double get _fraction {
    if (_dragFraction != null) return _dragFraction!;
    final ms = widget.duration.inMilliseconds;
    if (ms <= 0) return 0.0;
    return (widget.position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _onTap(TapDownDetails details, double trackWidth) {
    final fraction = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
    widget.onSeek(Duration(
      milliseconds: (fraction * widget.duration.inMilliseconds).round(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.duration - widget.position;
    final textStyle = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      color: const Color(0xFF6B6B6B),
    );

    return Column(
      children: [
        LayoutBuilder(builder: (ctx, constraints) {
          final trackWidth = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onTap(d, trackWidth),
            onHorizontalDragStart: (_) {},
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
                      (_dragFraction! * widget.duration.inMilliseconds).round(),
                ));
                setState(() => _dragFraction = null);
              }
            },
            child: SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track background
                  Container(
                    height: 4,
                    width: trackWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D0D5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Orange fill
                  Container(
                    height: 4,
                    width: _fraction * trackWidth,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Handle
                  Positioned(
                    left: (_fraction * trackWidth - 6).clamp(0.0, trackWidth - 12),
                    child: Container(
                      width: 12,
                      height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary,
                    ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(widget.position), style: textStyle),
            Text(
              remaining.isNegative ? '0:00' : '-${_fmt(remaining)}',
              style: textStyle,
            ),
          ],
        ),
      ],
    );
  }
}
