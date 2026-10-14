/// Bundled brand image assets (design-handoff v3), under `assets/design/`.
///
/// Content imagery (branch, event and announcement photos) is never bundled:
/// it comes from the Content Studio, through `usableMediaUrl`.
abstract final class AppAssets {
  static const String _base = 'assets/design';

  // ── Brand doves ────────────────────────────────────────────────────────────
  static const String doveWhite = '$_base/dove-white.png';
  static const String dovePurple = '$_base/dove-purple.png';
  static const String doveGold = '$_base/dove-gold.png';
  static const String doveInk = '$_base/dove-ink.png';

  /// Splash dove: the white line-art dove at 4x (468x440, drawn at 117x110),
  /// without the drop shadow of [doveWhite]. The native launch screen shows
  /// the same artwork at the same size and position (see pubspec.yaml).
  static const String splashDove = '$_base/splash-dove.png';

  // ── Onboarding photos ───────────────────────────────────────────────────────
  static const String communityRole = '$_base/community-role.jpg';

  // ── Player waveforms ────────────────────────────────────────────────────────
  static const String waveDark = '$_base/wave-dark.png';
  static const String waveLight = '$_base/wave-light.png';
}
