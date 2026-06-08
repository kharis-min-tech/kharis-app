import 'package:flutter/material.dart';

// 10 distinct gradient pairs for sermon artwork, cycling by index.
// Each pair is [startColor, endColor] for topLeft → bottomRight.
const _kGradients = <List<Color>>[
  [Color(0xFF1A0A3B), Color(0xFF6B34FA)],   // purple → deep blue/violet
  [Color(0xFF0A2A0A), Color(0xFF059669)],   // green → emerald
  [Color(0xFF3B1A0A), Color(0xFFF59E0B)],   // orange → amber
  [Color(0xFF0A1A3B), Color(0xFF4F46E5)],   // blue → indigo
  [Color(0xFF2A0A1A), Color(0xFFE11D48)],   // magenta → rose
  [Color(0xFF0A2A2A), Color(0xFF06B6D4)],   // teal → cyan
  [Color(0xFF2A1A0A), Color(0xFF92400E)],   // amber → brown
  [Color(0xFF0A1E2E), Color(0xFF38BDF8)],   // sky blue → blue
  [Color(0xFF1A0A2A), Color(0xFF8B5CF6)],   // deep purple → violet
  [Color(0xFF0A1A0A), Color(0xFF65A30D)],   // forest → olive
];

/// Returns a two-stop gradient colour list for sermon artwork.
/// Cycles through 10 distinct brand-adjacent pairs.
List<Color> sermonGradient(int index) =>
    _kGradients[index % _kGradients.length];
