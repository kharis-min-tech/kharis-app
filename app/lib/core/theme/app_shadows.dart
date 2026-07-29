import 'package:flutter/material.dart';

/// Shadow / border decoration tokens — Kharis Church design system v2.
/// No box shadows — elevation via colour contrast and borders only.
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

  /// Mini-player lift — `0 12px 30px rgba(0,0,0,.4)`.
  static const List<BoxShadow> miniPlayer = [
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 12), blurRadius: 30),
  ];

  /// Blur sigma for glassmorphic surfaces (mini player, overlays).
  static const double glassmorphicBlurSigma = 30;

  /// Glassmorphic decoration — bottom nav background gradient.
  static const BoxDecoration glassMorphicDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x00131313), // surfaceDark transparent
        Color(0xFF131313), // surfaceDark opaque
      ],
    ),
    border: Border(
      top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
    ),
  );
}
