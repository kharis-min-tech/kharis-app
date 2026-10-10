import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kharis_app/core/constants/app_assets.dart';

/// The brand dove on the splash, drawn in two beats.
///
/// 1. [trace]: a fine pen line runs along the centre of every brush stroke of
///    the logo, in drawing order, over a faint copy of the dove.
/// 2. [fill]: the brush-weight logo ([AppAssets.splashDove]) comes up to full
///    white while the pen line fades out, so the final frame is the logo
///    artwork itself, not a re-drawing of it.
///
/// The faint copy is what the native launch screen shows (the same artwork at
/// [launchOpacity], same size, centred), so the handover from the OS splash
/// to Flutter has no visible change before the pen starts.
class SplashDove extends StatelessWidget {
  const SplashDove({super.key, required this.trace, required this.fill});

  /// Pen progress along the whole outline, 0 to 1.
  final Animation<double> trace;

  /// Logo fill, 0 (faint launch copy) to 1 (full white logo).
  final Animation<double> fill;

  /// Logical size of [AppAssets.splashDove]: the 468x440 source drawn at 4x,
  /// which is also how flutter_native_splash sizes the launch image.
  static const Size size = Size(117, 110);

  /// Opacity of the dove on the native launch screen
  /// (`assets/native_splash/launch-dove.png` is [AppAssets.splashDove] with
  /// its alpha scaled by this). The animation starts from it.
  static const double launchOpacity = 0.24;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: fill.drive(Tween(begin: launchOpacity, end: 1)),
            child: Image.asset(
              AppAssets.splashDove,
              width: size.width,
              height: size.height,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          CustomPaint(
            painter: _DoveTracePainter(trace: trace, fill: fill),
          ),
        ],
      ),
    );
  }
}

class _DoveTracePainter extends CustomPainter {
  _DoveTracePainter({required this.trace, required this.fill})
    : super(repaint: Listenable.merge([trace, fill]));

  final Animation<double> trace;
  final Animation<double> fill;

  /// Pen width in logical pixels, about half the logo's brush weight.
  static const double _penWidth = 1.6;

  static final List<ui.PathMetric> _metrics = [
    for (final stroke in _doveStrokes)
      _smoothPath(stroke).computeMetrics().single,
  ];
  static final double _totalLength = _metrics.fold(
    0,
    (sum, m) => sum + m.length,
  );

  /// Quadratic curves through the midpoints of the traced polyline, so the
  /// pen draws curves rather than the corners of the simplified skeleton.
  static Path _smoothPath(List<double> xy) {
    final path = Path()..moveTo(xy[0], xy[1]);
    final count = xy.length ~/ 2;
    if (count == 2) return path..lineTo(xy[2], xy[3]);
    for (var i = 1; i < count - 1; i++) {
      final x = xy[i * 2], y = xy[i * 2 + 1];
      final nx = xy[i * 2 + 2], ny = xy[i * 2 + 3];
      path.quadraticBezierTo(x, y, (x + nx) / 2, (y + ny) / 2);
    }
    return path..lineTo(xy[xy.length - 2], xy[xy.length - 1]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = 1 - fill.value;
    final progress = trace.value;
    if (progress <= 0 || opacity <= 0) return;

    final scale = size.width / _sourceWidth;
    canvas.scale(scale, size.height / _sourceHeight);
    final pen = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _penWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    var remaining = progress * _totalLength;
    for (final metric in _metrics) {
      if (remaining <= 0) break;
      canvas.drawPath(
        metric.extractPath(0, math.min(remaining, metric.length)),
        pen,
      );
      remaining -= metric.length;
    }
  }

  @override
  bool shouldRepaint(_DoveTracePainter old) =>
      old.trace != trace || old.fill != fill;
}

/// Pixel size of the source artwork the strokes are measured in.
const double _sourceWidth = 468;
const double _sourceHeight = 440;

// dart format off
/// Centre lines of the logo's brush strokes in [AppAssets.splashDove] pixel
/// coordinates, as flat `x, y` pairs, one list per pen stroke in drawing
/// order: wing tops, right wing feathers, body and tail, left wing, then the
/// head and olive branch. Measured by thinning the artwork's alpha to a
/// one-pixel skeleton and simplifying it (0.9 px tolerance); regenerate them
/// if the artwork changes.
const List<List<double>> _doveStrokes = [
  [
    19.5, 17.5, 25.5, 13.5, 32.5, 11.5, 49.5, 11.5, 103.5, 29.5, 141.5,
    36.5, 185.5, 42.5, 209.5, 48.5, 215.5, 51.5, 224.5, 60.5, 231.5,
    73.5, 231.5, 76.5, 237.5, 91.5, 248.5, 102.5, 253.5, 102.5, 259.5,
    99.5, 270.5, 86.5, 276.5, 83.5, 286.5, 82.5, 289.5, 72.5, 298.5,
    58.5, 308.5, 49.5, 319.5, 45.5, 383.5, 39.5, 429.5, 29.5, 450.5,
    29.5, 456.5, 34.5, 456.5, 42.5, 453.5, 51.5,
  ],
  [
    447.5, 79.5, 447.5, 81.5, 441.5, 88.5, 428.5, 97.5, 426.5, 105.5,
    429.5, 108.5, 427.5, 117.5, 419.5, 123.5, 416.5, 127.5,
  ],
  [
    407.5, 154.5, 405.5, 161.5, 403.5, 163.5, 387.5, 170.5, 384.5,
    179.5, 379.5, 184.5, 377.5, 189.5, 374.5, 192.5, 369.5, 194.5,
    364.5, 194.5, 355.5, 190.5, 328.5, 162.5, 320.5, 159.5, 313.5,
    162.5, 311.5, 165.5, 311.5, 175.5, 313.5, 180.5, 311.5, 200.5,
    302.5, 216.5, 299.5, 219.5, 296.5, 229.5, 288.5, 235.5, 276.5,
    252.5, 272.5, 262.5, 272.5, 269.5, 270.5, 275.5,
  ],
  [
    296.5, 230.5, 298.5, 231.5, 308.5, 246.5, 332.5, 269.5, 354.5,
    284.5, 379.5, 296.5, 385.5, 302.5, 385.5, 311.5, 380.5, 316.5,
    375.5, 317.5, 367.5, 322.5, 362.5, 328.5,
  ],
  [
    360.5, 350.5, 350.5, 371.5, 343.5, 378.5, 334.5, 381.5, 325.5,
    381.5, 322.5, 376.5, 322.5, 370.5,
  ],
  [
    322.5, 383.5, 324.5, 381.5, 321.5, 383.5, 320.5, 396.5, 318.5,
    403.5, 311.5, 408.5, 306.5, 407.5,
  ],
  [
    268.5, 350.5, 267.5, 379.5, 274.5, 404.5, 274.5, 412.5, 270.5,
    420.5, 261.5, 424.5, 254.5, 424.5, 242.5, 420.5, 226.5, 421.5,
    217.5, 423.5, 209.5, 421.5, 204.5, 416.5, 203.5, 370.5, 202.5,
    369.5, 197.5, 370.5, 190.5, 378.5, 184.5, 392.5, 183.5, 398.5,
    178.5, 403.5, 170.5, 406.5, 165.5, 405.5, 151.5, 392.5, 146.5,
    389.5, 138.5, 389.5, 133.5, 387.5, 129.5, 381.5, 129.5, 376.5,
    131.5, 371.5,
  ],
  [
    123.5, 351.5, 118.5, 355.5, 114.5, 356.5, 95.5, 335.5, 89.5, 326.5,
    87.5, 320.5, 87.5, 313.5, 90.5, 307.5, 99.5, 298.5, 118.5, 286.5,
    153.5, 271.5, 158.5, 270.5, 183.5, 256.5, 197.5, 241.5, 200.5,
    226.5, 197.5, 220.5, 191.5, 214.5, 180.5, 207.5, 129.5, 188.5,
    107.5, 177.5, 101.5, 172.5, 95.5, 161.5, 91.5, 157.5, 74.5, 148.5,
    67.5, 140.5, 67.5, 128.5, 70.5, 120.5, 69.5, 111.5, 44.5, 106.5,
    35.5, 102.5, 31.5, 98.5, 27.5, 91.5, 24.5, 78.5, 11.5, 62.5, 9.5,
    56.5, 9.5, 49.5, 11.5, 41.5,
  ],
  [
    214.5, 185.5, 223.5, 182.5, 243.5, 183.5, 259.5, 169.5, 261.5,
    164.5, 264.5, 161.5, 276.5, 161.5, 282.5, 155.5, 284.5, 148.5,
    281.5, 142.5, 281.5, 136.5,
  ],
  [
    285.5, 146.5, 290.5, 145.5, 292.5, 141.5, 295.5, 139.5, 304.5,
    139.5, 308.5, 140.5, 311.5, 143.5,
  ],
  [
    315.5, 141.5, 313.5, 141.5, 310.5, 144.5, 309.5, 151.5, 304.5,
    155.5, 300.5, 163.5,
  ],
  [309.5, 150.5, 317.5, 158.5],
  [328.5, 132.5, 332.5, 130.5, 346.5, 128.5],
  [
    293.5, 140.5, 291.5, 138.5, 291.5, 131.5, 298.5, 117.5, 298.5,
    113.5, 300.5, 109.5, 300.5, 97.5, 297.5, 90.5, 291.5, 84.5, 286.5,
    83.5,
  ],
  [274.5, 162.5, 272.5, 172.5, 267.5, 182.5, 267.5, 186.5],
  [261.5, 163.5, 263.5, 160.5, 255.5, 160.5, 244.5, 163.5],
  [242.5, 184.5, 240.5, 195.5, 237.5, 199.5, 234.5, 208.5],
  [229.5, 183.5, 227.5, 188.5, 224.5, 191.5, 210.5, 195.5],
  [208.5, 321.5, 208.5, 325.5, 205.5, 332.5, 202.5, 368.5],
];
// dart format on
