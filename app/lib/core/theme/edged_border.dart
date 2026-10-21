import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The Kharis website's button shape: square corners, an optional 1px ring,
/// and a solid [edge] along the bottom ([edgeWidth] tall, no blur), which
/// reads as a pressable slab rather than a floating pill.
class EdgedBorder extends OutlinedBorder {
  const EdgedBorder({
    required this.edge,
    this.edgeWidth = 2,
    super.side = BorderSide.none,
  });

  final Color edge;
  final double edgeWidth;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: edgeWidth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawRect(rect.deflate(side.width / 2), side.toPaint());
    }
    if (edgeWidth > 0) {
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left,
          rect.bottom - edgeWidth,
          rect.right,
          rect.bottom,
        ),
        Paint()..color = edge,
      );
    }
  }

  @override
  EdgedBorder copyWith({BorderSide? side, Color? edge, double? edgeWidth}) =>
      EdgedBorder(
        side: side ?? this.side,
        edge: edge ?? this.edge,
        edgeWidth: edgeWidth ?? this.edgeWidth,
      );

  @override
  ShapeBorder scale(double t) =>
      EdgedBorder(side: side.scale(t), edge: edge, edgeWidth: edgeWidth * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is EdgedBorder) {
      return EdgedBorder(
        side: BorderSide.lerp(a.side, side, t),
        edge: Color.lerp(a.edge, edge, t)!,
        edgeWidth: lerpDouble(a.edgeWidth, edgeWidth, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  bool operator ==(Object other) =>
      other is EdgedBorder &&
      other.side == side &&
      other.edge == edge &&
      other.edgeWidth == edgeWidth;

  @override
  int get hashCode => Object.hash(side, edge, edgeWidth);
}
