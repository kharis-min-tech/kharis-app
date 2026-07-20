import 'package:flutter/material.dart';

// 10 distinct gradient pairs for sermon artwork, cycling by index.
// Each pair is [startColor, endColor] for topLeft → bottomRight.
const _kGradients = <List<Color>>[
  [Color(0xFF1C1410), Color(0xFFFD7F20)],   // charcoal → brand orange
  [Color(0xFF17122B), Color(0xFF9A8FB8)],   // deep heather → muted heather
  [Color(0xFF2A1608), Color(0xFFFF8A3C)],   // umber → ember
  [Color(0xFF14141A), Color(0xFF6E6A8A)],   // slate charcoal → dusk slate
  [Color(0xFF241206), Color(0xFFE0762A)],   // burnt charcoal → warm orange
  [Color(0xFF1B1712), Color(0xFFCBB9A2)],   // ash → warm sand
  [Color(0xFF2A1A0A), Color(0xFF92400E)],   // amber → brown
  [Color(0xFF121014), Color(0xFF8A6FA8)],   // charcoal → heather
  [Color(0xFF201008), Color(0xFFB85C1E)],   // ember dark → rust
  [Color(0xFF16130E), Color(0xFF9C8465)],   // ash → tan
];

/// Returns a two-stop gradient colour list for sermon artwork.
/// Cycles through 10 distinct brand-adjacent pairs.
List<Color> sermonGradient(int index) =>
    _kGradients[index % _kGradients.length];
