/// Design-system image assets (design-handoff v3).
///
/// Bundled under `assets/design/`. City and event photos are looked up by key
/// so data layers can store a short slug (e.g. `london-hq`) rather than a path.
abstract final class AppAssets {
  static const String _base = 'assets/design';

  // ── Brand doves ────────────────────────────────────────────────────────────
  static const String doveWhite = '$_base/dove-white.png';
  static const String dovePurple = '$_base/dove-purple.png';
  static const String doveGold = '$_base/dove-gold.png';
  static const String doveInk = '$_base/dove-ink.png';

  // ── Onboarding photos ───────────────────────────────────────────────────────
  static const String splashWorship = '$_base/splash-worship.png';
  static const String splashPink = '$_base/splash-pink.jpg';

  /// Full-bleed splash background: [splashPink] pre-cropped to the same
  /// BoxFit.cover framing at 1242x2688. Generated for the native splash, and
  /// used by SplashScreen too so both show identical pixels — the source jpg
  /// is only 206x206 and visibly softens when the widget upscales it.
  static const String splashBg = '$_base/splash-bg.png';
  static const String communityRole = '$_base/community-role.jpg';

  // ── Sermon / series art ─────────────────────────────────────────────────────
  static const String sermonPopular = '$_base/popular.png';
  static const String sermonCrisis = '$_base/crisis.png';
  static const String sermonMission = '$_base/mission.png';
  static const String sermonLight = '$_base/light.png';
  static const String seriesActs = '$_base/acts-series.png';
  static const String seriesFasting = '$_base/fasting.png';

  // ── Player waveforms ────────────────────────────────────────────────────────
  static const String waveDark = '$_base/wave-dark.png';
  static const String waveLight = '$_base/wave-light.png';

  /// City landmark photo for a branch slug (e.g. `london-hq`, `kp2-london`).
  static String city(String slug) => '$_base/city-$slug.jpg';

  /// Event banner photo for an event slug (e.g. `sunday`, `worship`).
  static String event(String slug) => '$_base/evt-$slug.jpg';
}
