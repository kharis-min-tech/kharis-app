/// Spacing scale in logical pixels.
/// Consumed as padding, gap, and margin values throughout the app.
abstract final class AppSpacing {
  /// 4 px — tight nudges, icon-to-label gaps.
  static const double xs = 4;

  /// 8 px — intra-component spacing.
  static const double sm = 8;

  /// 12 px — compact padding inside cards and chips.
  static const double md = 12;

  /// 16 px — default section padding, list item vertical spacing.
  static const double lg = 16;

  /// 20 px — comfortable content padding.
  static const double xl = 20;

  /// 24 px — section-level breathing room.
  static const double xxl = 24;

  /// 32 px — large section separators and screen margins.
  static const double xxxl = 32;
}
