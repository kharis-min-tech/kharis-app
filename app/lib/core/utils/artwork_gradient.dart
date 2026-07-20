import 'package:flutter/material.dart';

// 10 distinct gradient pairs for sermon artwork, cycling by index.
// Each pair is [startColor, endColor] for topLeft → bottomRight.
// Website hue families only (purple #6B34FA, orange #FD7F20, magenta
// #800654) — rich and saturated because white text sits on top.
// No teal/green.
const _kGradients = <List<Color>>[
  [Color(0xFF1A0A3B), Color(0xFF6B34FA)], // deep violet → brand purple
  [Color(0xFF3B1A0A), Color(0xFFFD7F20)], // deep umber → brand orange
  [Color(0xFF33041F), Color(0xFF800654)], // near-black plum → brand magenta
  [Color(0xFF241060), Color(0xFF7C3AED)], // indigo-violet → violet
  [Color(0xFF2A0A1A), Color(0xFFE11D48)], // magenta-rose family
  [Color(0xFF40200A), Color(0xFFF59E0B)], // amber (orange family)
  [Color(0xFF150A2A), Color(0xFF9D6BFF)], // dusk → soft violet
  [Color(0xFF2A0A05), Color(0xFFE2590F)], // burnt orange
  [Color(0xFF1F0A33), Color(0xFF5B21B6)], // deep purple
  [Color(0xFF3B0A2A), Color(0xFFC2185B)], // wine → bright magenta
];

/// Returns a two-stop gradient colour list for sermon artwork.
/// Cycles through 10 distinct brand-adjacent pairs (purple, orange,
/// magenta families from kharis.org).
List<Color> sermonGradient(int index) =>
    _kGradients[index % _kGradients.length];
