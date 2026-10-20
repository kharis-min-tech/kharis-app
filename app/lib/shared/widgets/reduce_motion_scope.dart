import 'package:flutter/widgets.dart';

/// Makes the member's reduced-motion setting reach every
/// `MediaQuery.disableAnimationsOf` check on both platforms.
///
/// Flutter reports Android's "Remove animations" as
/// [MediaQueryData.disableAnimations], but iOS's Reduce Motion only as
/// `accessibilityFeatures.reduceMotion`, which [MediaQuery] does not carry.
/// Under this scope either one sets `disableAnimations`, and turning the
/// setting on or off while the app runs takes effect at once.
class ReduceMotionScope extends StatefulWidget {
  const ReduceMotionScope({super.key, required this.child});

  final Widget child;

  @override
  State<ReduceMotionScope> createState() => _ReduceMotionScopeState();
}

class _ReduceMotionScopeState extends State<ReduceMotionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final reduce = View.of(
      context,
    ).platformDispatcher.accessibilityFeatures.reduceMotion;
    if (!reduce || data.disableAnimations) return widget.child;
    return MediaQuery(
      data: data.copyWith(disableAnimations: true),
      child: widget.child,
    );
  }
}
