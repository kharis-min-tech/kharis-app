import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Builds a colour scheme from the artwork at a URL, or null when the image
/// cannot be read.
typedef ArtworkSchemeSource =
    Future<ColorScheme?> Function(String artworkUrl, Brightness brightness);

/// Where the player's artwork colour comes from. Tests override this so no
/// image is fetched or decoded.
final artworkSchemeSourceProvider = Provider<ArtworkSchemeSource>(
  (ref) => schemeFromArtwork,
);

/// The scheme for one artwork in one brightness, extracted once per session.
final artworkSchemeProvider =
    FutureProvider.family<ColorScheme?, (String, Brightness)>(
      (ref, key) => ref.watch(artworkSchemeSourceProvider)(key.$1, key.$2),
    );

/// Flutter's own extraction ([ColorScheme.fromImageProvider]): the artwork's
/// dominant colour as the seed of a Material tonal scheme. Reads through the
/// same disk cache the artwork tiles fill, so the image is rarely fetched
/// twice. Any failure (offline, broken image, timeout) yields null.
Future<ColorScheme?> schemeFromArtwork(
  String artworkUrl,
  Brightness brightness,
) async {
  try {
    return await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(artworkUrl),
      brightness: brightness,
    );
  } catch (_) {
    return null;
  }
}

/// WCAG 2 contrast ratio between [a] and [b] (alpha is composited over [b]).
double contrastRatio(Color a, Color b) {
  final la = Color.alphaBlend(a, b).computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG AA for body text.
const double kTextContrastAA = 4.5;

/// [base] re-pointed at a solid surface in the artwork's colour, for the top
/// of the player: the dark scheme's primary container in dark mode, a light
/// wash of the light scheme's in light mode. Every text colour is checked
/// against the new surfaces and swapped for one that passes WCAG AA, so the
/// widgets underneath keep reading `context.kc` unchanged. Flat fills only:
/// no gradient, no glow.
KharisColors tintedPlayerColors(
  KharisColors base,
  ColorScheme scheme,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;
  final tint = dark
      ? scheme.primaryContainer.withValues(alpha: 1)
      : Color.alphaBlend(
          scheme.primaryContainer.withValues(alpha: 0.5),
          base.bg,
        );

  final fg = _firstLegible(
    [base.onBg, scheme.onPrimaryContainer, Colors.white, Colors.black],
    [tint],
  );
  // Pills and tracks (mode toggle, speed pill) sit one step off the tint.
  final raised = Color.alphaBlend(fg.withValues(alpha: 0.08), tint);
  final surfaces = [tint, raised];
  final muted = _firstLegible([
    base.muted,
    Color.alphaBlend(fg.withValues(alpha: 0.78), tint),
    fg,
  ], surfaces);

  return base.copyWith(
    bg: tint,
    surface: dark
        ? Color.alphaBlend(fg.withValues(alpha: 0.12), tint)
        : base.surface,
    surfaceAlt: raised,
    surfaceMuted: raised,
    chipBg: raised,
    onBg: fg,
    muted: muted,
    faint: muted,
    divider: fg.withValues(alpha: 0.14),
    outline: fg.withValues(alpha: 0.2),
    onChip: _firstLegible([base.onChip, fg], surfaces),
    accentInk: _firstLegible([base.accentInk, fg], surfaces),
  );
}

/// The first of [candidates] that reaches AA on every one of [surfaces], or
/// the most legible one when none does.
Color _firstLegible(List<Color> candidates, List<Color> surfaces) {
  double worst(Color c) =>
      surfaces.map((s) => contrastRatio(c, s)).reduce((a, b) => a < b ? a : b);
  for (final c in candidates) {
    if (worst(c) >= kTextContrastAA) return c;
  }
  return candidates.reduce((a, b) => worst(a) >= worst(b) ? a : b);
}
