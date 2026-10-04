import 'package:flutter/material.dart';

/// Shadow / border decoration tokens. Light surfaces use the single soft,
/// neutral [card] shadow; dark surfaces rely on colour contrast instead.
/// There are deliberately no coloured glows, glass blurs or heavy lifts here
/// (DESIGN.md: "No glows", "No glassmorphism").
abstract final class AppShadows {
  /// 1px white 10% border — applied to cards and elevated surfaces.
  static const Border cardBorder = Border.fromBorderSide(
    BorderSide(color: Color(0x1AFFFFFF), width: 1),
  );

  /// 2px gold border — applied to focused inputs and active interactive
  /// elements.
  static const Border focusBorder = Border.fromBorderSide(
    BorderSide(color: Color(0xFFE9C349), width: 2),
  );

  /// Soft card shadow on light surfaces — `0 2px 12px rgba(30,20,60,.05)`.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D1E143C), offset: Offset(0, 2), blurRadius: 12),
  ];
}
