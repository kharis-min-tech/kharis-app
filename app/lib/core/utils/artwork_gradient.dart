import 'package:flutter/material.dart';

// 10 distinct gradient pairs for sermon artwork, cycling by index.
// Each pair is [startColor, endColor] for topLeft → bottomRight.
// Midnight & Copper v3: muted, cinematic pairs — no vivid pop.
const _kGradients = <List<Color>>[
  [Color(0xFF0E1B33), Color(0xFF3E5C8F)],   // midnight navy → steel blue
  [Color(0xFF1C1206), Color(0xFFC4794A)],   // deep bronze → copper
  [Color(0xFF0A2A21), Color(0xFF2E7D64)],   // deep pine → muted emerald
  [Color(0xFF101828), Color(0xFF5A7DAB)],   // midnight → dusty blue
  [Color(0xFF251015), Color(0xFF8F4A5B)],   // wine → muted rose
  [Color(0xFF0A2328), Color(0xFF3B7A8A)],   // deep teal → slate teal
  [Color(0xFF231409), Color(0xFF8A5A2E)],   // umber → bronze
  [Color(0xFF0D1F2E), Color(0xFF6B93B8)],   // deep sky → steel
  [Color(0xFF161226), Color(0xFF5E5488)],   // indigo slate → muted violet
  [Color(0xFF12200E), Color(0xFF6B7D3F)],   // forest → olive
];

/// Returns a two-stop gradient colour list for sermon artwork.
/// Cycles through 10 distinct brand-adjacent pairs.
List<Color> sermonGradient(int index) =>
    _kGradients[index % _kGradients.length];
