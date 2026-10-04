import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Player timeline scrubber.
///
/// A thin rounded track: the played portion is filled solid up to the exact
/// `position / duration` fraction, the rest is a faint rail, and a round thumb
/// marks the play head. Tap or drag anywhere to seek; the thumb grows while
/// dragging. Time labels sit below — elapsed on the left, time remaining
/// (`-m:ss`) on the right.
///
/// Until the engine reports a duration the timeline is inert: gestures are
/// ignored (a tap would otherwise compute 0:00 and throw the member back to
/// the start) and the unknown times read `--:--`.
///
/// [pins] mark the member's notes on this timeline: a small gold bead on the
/// rail per note, so the moments they pinned are visible while scrubbing.
/// Positions must already be on the timeline this bar draws (the caller maps
/// audio-timeline notes onto a video timeline). See [pinCentres].
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.pins = const <Duration>[],
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  /// Note positions on this bar's timeline.
  final List<Duration> pins;

  /// Radius of a pin's gold core.
  static const pinRadius = 3.0;

  /// Ring in the page colour around each pin, separating it from the solid
  /// played fill and the faint rail alike.
  static const pinHalo = 1.5;

  /// Full painted width of one pin, halo included. Pins closer than this
  /// would overlap, so they merge into one marker.
  static const pinWidth = 2 * (pinRadius + pinHalo);

  /// The x centre of every pin marker on a track [width] wide.
  ///
  /// Pins outside `[0, duration]` are dropped and nothing is placed while
  /// [duration] is unknown. Centres are clamped so a whole marker stays inside
  /// the track, then any marker closer than [pinWidth] to the one before it
  /// is merged into that one (which keeps the earliest position).
  @visibleForTesting
  static List<double> pinCentres(
    List<Duration> pins, {
    required Duration duration,
    required double width,
  }) {
    final total = duration.inMicroseconds;
    if (total <= 0 || width <= 0 || pins.isEmpty) return const <double>[];
    const half = pinWidth / 2;
    final lo = half < width / 2 ? half : width / 2;
    final hi = width - lo;
    final xs = [
      for (final pin in pins)
        if (pin >= Duration.zero && pin <= duration)
          pin.inMicroseconds * width / total,
    ]..sort();
    final centres = <double>[];
    for (final raw in xs) {
      final x = raw.clamp(lo, hi);
      if (centres.isEmpty || x - centres.last >= pinWidth) centres.add(x);
    }
    return centres;
  }

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

  bool get _known => widget.duration > Duration.zero;

  /// Notes this bar actually marks: none until the duration is known, and
  /// never one outside the timeline. Counted before merging, so the spoken
  /// count matches the member's notes, not the painted beads.
  int get _pinCount {
    if (!_known) return 0;
    var count = 0;
    for (final pin in widget.pins) {
      if (pin >= Duration.zero && pin <= widget.duration) count++;
    }
    return count;
  }

  String get _label {
    final count = _pinCount;
    if (count == 0) return 'Playback position';
    return 'Playback position, $count ${count == 1 ? 'note' : 'notes'} '
        'on this message';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kc;
    final timeStyle = AppTypography.ui(
      size: 11.5,
      weight: FontWeight.w600,
      color: colors.muted,
    );

    final known = _known;
    final elapsed = _displayPosition;
    final remaining = widget.duration > elapsed
        ? widget.duration - elapsed
        : Duration.zero;

    final track = LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final paint = SizedBox(
          height: _hitHeight,
          width: width,
          child: CustomPaint(
            painter: _TimelinePainter(
              fraction: _fraction,
              dragging: _dragFraction != null,
              showThumb: known,
              played: colors.onBg,
              rail: colors.onBg.withValues(alpha: 0.22),
              pins: SeekBar.pinCentres(
                widget.pins,
                duration: widget.duration,
                width: width,
              ),
              pin: colors.accentInk,
              pinHalo: colors.bg,
            ),
          ),
        );
        if (!known) return paint;
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
          onHorizontalDragCancel: () => setState(() => _dragFraction = null),
          child: paint,
        );
      },
    );

    return Semantics(
      slider: true,
      enabled: known,
      label: _label,
      value: known ? '${_fmt(elapsed)} of ${_fmt(widget.duration)}' : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          track,
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                known || elapsed > Duration.zero ? _fmt(elapsed) : _unknown,
                style: timeStyle,
              ),
              Text(known ? '-${_fmt(remaining)}' : _unknown, style: timeStyle),
            ],
          ),
        ],
      ),
    );
  }

  static const _unknown = '--:--';
}

/// Thin rounded rail, solid fill up to [fraction], a gold bead per note pin,
/// round thumb at the head (drawn last, so it rides over a pin it reaches).
class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.fraction,
    required this.dragging,
    required this.showThumb,
    required this.played,
    required this.rail,
    required this.pins,
    required this.pin,
    required this.pinHalo,
  });

  final double fraction;
  final bool dragging;

  /// Hidden while the duration is unknown, so the inert rail does not look
  /// draggable.
  final bool showThumb;
  final Color played;
  final Color rail;

  /// Pin centres along the track, from [SeekBar.pinCentres].
  final List<double> pins;
  final Color pin;
  final Color pinHalo;

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

    if (pins.isNotEmpty) {
      final halo = Paint()..color = pinHalo;
      final core = Paint()..color = pin;
      for (final x in pins) {
        final centre = Offset(x, cy);
        canvas
          ..drawCircle(centre, SeekBar.pinRadius + SeekBar.pinHalo, halo)
          ..drawCircle(centre, SeekBar.pinRadius, core);
      }
    }

    if (!showThumb) return;
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
      old.showThumb != showThumb ||
      old.played != played ||
      old.rail != rail ||
      old.pin != pin ||
      old.pinHalo != pinHalo ||
      !listEquals(old.pins, pins);
}
