import 'package:flutter/material.dart';

import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_typography.dart';

/// Player scrubber — dark design-handoff (v3).
///
/// Renders the `wave-dark` waveform image: the played portion is tinted gold
/// while the remaining portion stays muted lavender. Tap or drag anywhere on
/// the wave to seek. Time labels sit below — elapsed on the left, total
/// duration on the right — both in a muted dark tone.
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

  // Fraction (0.0–1.0) to display, accounting for a live drag.
  double get _fraction {
    if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0.0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _displayPosition {
    if (_dragFraction != null) {
      return Duration(
        milliseconds:
            (_dragFraction! * widget.duration.inMilliseconds).round(),
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
      color: AppColors.darkMuted,
    );

    const waveH = 46.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(builder: (_, constraints) {
          final trackWidth = constraints.maxWidth;
          final fillWidth = (_fraction * trackWidth).clamp(0.0, trackWidth);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _seekToFraction((d.localPosition.dx / trackWidth).clamp(0.0, 1.0)),
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Unplayed waveform (muted).
                  Image.asset(
                    AppAssets.waveDark,
                    fit: BoxFit.cover,
                    color: AppColors.darkMuted.withValues(alpha: 0.45),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  // Played waveform (gold), clipped to progress.
                  ClipRect(
                    clipper: _WidthClipper(fillWidth),
                    child: Image.asset(
                      AppAssets.waveDark,
                      fit: BoxFit.cover,
                      color: AppColors.gold,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                ],
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

class _WidthClipper extends CustomClipper<Rect> {
  const _WidthClipper(this.width);

  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_WidthClipper oldClipper) => oldClipper.width != width;
}
