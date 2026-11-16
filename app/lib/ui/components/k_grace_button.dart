import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_dove_mark.dart';

/// The floating Grace button: a highlight orb with the dove on it and a soft
/// halo behind, in a 56 hit area. It bobs 5 over 2.8 s while the halo
/// pulses; with reduce motion on it stays still.
///
/// Place it in the page Stack, `KSize.graceRight` from the end and
/// `KSize.graceBottom` from the bottom (`KSize.graceBottomReader` on the
/// reader).
class KGraceButton extends StatefulWidget {
  const KGraceButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback? onPressed;

  /// For example "Ask Grace, your Bible companion".
  final String semanticLabel;

  @override
  State<KGraceButton> createState() => _KGraceButtonState();
}

class _KGraceButtonState extends State<KGraceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: KMotion.graceBob,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _bob
        ..stop()
        ..value = 0;
    } else if (!_bob.isAnimating) {
      _bob.repeat();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  // The orb is lit from the upper left, as on the canvas: the gradient is
  // centred 35% across and 30% down, reaches 75% of the orb, and holds the
  // plain highlight colour at 60%.
  static const Alignment _lightFrom = Alignment(-0.3, -0.4);
  static const double _lightReach = 0.75;
  static const List<double> _lightStops = [0, 0.6, 1];

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    final orb = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: KShadow.grace,
        gradient: RadialGradient(
          center: _lightFrom,
          radius: _lightReach,
          colors: [k.highlightLight, k.highlight, k.highlightDeep],
          stops: _lightStops,
        ),
      ),
      child: SizedBox.square(
        dimension: KSize.graceOrb,
        child: Center(
          child: KDoveMark(size: KSize.graceMark, color: k.primary),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: SizedBox.square(
          dimension: KSize.graceSize,
          child: AnimatedBuilder(
            animation: _bob,
            child: orb,
            builder: (context, child) {
              // 0 at rest, 1 at the top of the bob, eased both ways.
              final half = _bob.value < 0.5 ? _bob.value : 1 - _bob.value;
              final rise = Curves.easeInOut.transform(half * 2);
              final halo =
                  KRatio.graceHalo -
                  (KRatio.graceHalo - KRatio.graceHaloLow) * half * 2;
              return Transform.translate(
                offset: Offset(0, -KSize.graceBobTravel * rise),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k.highlight.withValues(alpha: halo),
                      ),
                      child: const SizedBox.square(dimension: KSize.graceHalo),
                    ),
                    child!,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
