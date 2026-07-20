import 'package:flutter/material.dart';

// 10 distinct gradient pairs for sermon artwork, cycling by index.
// Each pair is [startColor, endColor] for topLeft → bottomRight.
const _kGradients = <List<Color>>[
  [Color(0xFF241230), Color(0xFFD9B36C)],   // plum → champagne gold
  [Color(0xFF2A0F1E), Color(0xFFD8B8C6)],   // aubergine → rose quartz
  [Color(0xFF1E1433), Color(0xFFB9A6E8)],   // deep violet → soft lavender
  [Color(0xFF2E1B0A), Color(0xFFE8C77E)],   // umber → warm gold
  [Color(0xFF321226), Color(0xFFC98BA8)],   // dark plum → dusty rose
  [Color(0xFF1B0F2E), Color(0xFF8F76C9)],   // indigo plum → muted violet
  [Color(0xFF33200A), Color(0xFFC9A15A)],   // bronze → antique gold
  [Color(0xFF260D18), Color(0xFFB786A0)],   // wine → mauve
  [Color(0xFF150C1A), Color(0xFF4A3670)],   // near-black plum → royal plum
  [Color(0xFF2A1932), Color(0xFF9C7FD6)],   // plum subtle → lavender
];

/// Returns a two-stop gradient colour list for sermon artwork.
/// Cycles through 10 distinct brand-adjacent pairs.
List<Color> sermonGradient(int index) =>
    _kGradients[index % _kGradients.length];
