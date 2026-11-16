/// Bundled brand image assets, under `assets/design/`.
///
/// Content imagery (branch, event and announcement photos) is never bundled:
/// it comes from the Content Studio, through `usableMediaUrl`.
abstract final class AppAssets {
  static const String _base = 'assets/design';

  /// Splash dove: the white line-art dove at 4x (468x440, drawn at 117x110).
  /// The native launch screen shows the same artwork at the same size and
  /// position (see pubspec.yaml).
  static const String splashDove = '$_base/splash-dove.png';

  // ── Onboarding photos ───────────────────────────────────────────────────────
  static const String communityRole = '$_base/community-role.jpg';
}
