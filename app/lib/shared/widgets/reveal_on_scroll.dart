import 'package:flutter/material.dart';

/// How far a section rises as it appears.
const double kRevealRise = 8;

/// How long a section takes to appear.
const Duration kRevealDuration = Duration(milliseconds: 280);

/// Where on the screen a section's top must reach before it appears, as a
/// share of the viewport's height from its top.
const double kRevealLine = 0.85;

/// Emil Kowalski's ease-out: quick to start, soft to land.
const Curve kRevealCurve = Cubic(0.23, 1, 0.32, 1);

/// Lets every [RevealOnScroll] below follow one scroll view.
class RevealScope extends InheritedWidget {
  const RevealScope({super.key, required this.scroll, required super.child});

  final ScrollController scroll;

  static ScrollController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RevealScope>()?.scroll;

  @override
  bool updateShouldNotify(RevealScope old) => scroll != old.scroll;
}

/// Shows [child] as the member scrolls to it: it rises [kRevealRise] px and
/// fades in over [kRevealDuration] once its top passes [kRevealLine] of the
/// screen, then stays. What is on the first screen is simply there, nothing
/// replays on the way back up, taps are never blocked, and with reduced
/// motion (or no [RevealScope]) the section is always shown as is.
class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({super.key, required this.child});

  final Widget child;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: kRevealDuration,
  );
  late final Animation<double> _eased = CurvedAnimation(
    parent: _shown,
    curve: kRevealCurve,
  );
  ScrollController? _scroll;

  /// Whether the section has been placed (shown or waiting); decided once,
  /// after its first layout.
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = RevealScope.maybeOf(context);
    final still = MediaQuery.disableAnimationsOf(context);
    if (scroll == null || still) {
      _stopFollowing();
      _shown.value = 1;
      _decided = true;
      return;
    }
    if (scroll != _scroll && !_decided) {
      _stopFollowing();
      _scroll = scroll..addListener(_check);
      WidgetsBinding.instance.addPostFrameCallback((_) => _firstCheck());
    }
  }

  @override
  void dispose() {
    _stopFollowing();
    _shown.dispose();
    super.dispose();
  }

  void _stopFollowing() {
    _scroll?.removeListener(_check);
    _scroll = null;
  }

  /// Distance of the section's top from the viewport's, or null before
  /// layout.
  double? _top() {
    final box = context.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  bool _reached(double top) =>
      top < MediaQuery.sizeOf(context).height * kRevealLine;

  void _firstCheck() {
    final top = _top();
    if (top == null) return;
    _decided = true;
    if (_reached(top)) {
      // On the first screen: there from the start, no entrance.
      _shown.value = 1;
      _stopFollowing();
    }
  }

  /// A check is waiting for the frame being laid out.
  bool _pending = false;

  /// The scroll moves before the frame is laid out: measure after it, once
  /// per frame however many scroll updates arrive.
  void _check() {
    if (_pending || !_decided || _shown.value > 0 || _shown.isAnimating) {
      return;
    }
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted || _shown.value > 0 || _shown.isAnimating) return;
      final top = _top();
      if (top != null && _reached(top)) {
        _stopFollowing();
        _shown.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _eased,
      child: AnimatedBuilder(
        animation: _eased,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _eased.value) * kRevealRise),
          child: child,
        ),
      ),
    );
  }
}
