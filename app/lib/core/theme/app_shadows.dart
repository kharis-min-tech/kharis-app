import 'package:flutter/material.dart';

/// Shadow / border decoration tokens — Kharis Church design system v6
/// "Daylight". Cards use the kharis.org shadow (0 0 30px rgba(0,0,0,0.18));
/// buttons carry no shadow.
abstract final class AppShadows {
  /// 1px hairline border — applied to cards and elevated surfaces.
  static const Border cardBorder = Border.fromBorderSide(
    BorderSide(color: Color(0x14000000), width: 1),
  );

  /// Website card shadow — 0 0 30px rgba(0,0,0,0.18).
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 30),
  ];

  /// 2px orange border — applied to focused inputs and active interactive
  /// elements.
  static const Border focusBorder = Border.fromBorderSide(
    BorderSide(color: Color(0xFFFD7F20), width: 2),
  );

  /// Blur sigma for blurred surfaces (mini player, overlays).
  static const double glassmorphicBlurSigma = 30;

  /// Bottom nav background fade — white bar over content.
  static const BoxDecoration glassMorphicDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x00FFFFFF), // white transparent
        Color(0xFFFFFFFF), // white opaque
      ],
    ),
    border: Border(top: BorderSide(color: Color(0x14000000), width: 1)),
  );
}
