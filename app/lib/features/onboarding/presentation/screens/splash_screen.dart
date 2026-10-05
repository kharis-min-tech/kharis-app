import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/splash_dove.dart';

/// Splash / brand entry.
///
/// Solid ink, the dove centred exactly where the native launch screen draws
/// it. The dove's outline draws itself in and fills, the "Kharis" wordmark
/// and tagline fade up beneath it, then the gold **Get started** CTA and the
/// "I already have an account" row appear. Button-driven (no auto-advance)
/// so returning users are routed by the auth redirect and new users choose
/// to begin. With reduce motion on, the first frame is the final state.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // One timeline, about 2.1 s: pen trace ~0.95 s, fill 0.35 s, wordmark and
  // tagline 0.45 s, then the actions 0.4 s, each beat ease-out and slightly
  // overlapping the last so the sequence reads as one gesture.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final Animation<double> _trace = _beat(0.05, 0.5, Curves.easeInOut);
  late final Animation<double> _fill = _beat(0.48, 0.65, Curves.easeOut);
  late final Animation<double> _title = _beat(0.6, 0.82, Curves.easeOut);
  late final Animation<double> _actions = _beat(0.8, 1, Curves.easeOut);
  bool _started = false;

  Animation<double> _beat(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _entry,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entry.value = 1;
    } else {
      _entry.forward();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = KharisColors.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Theme-invariant: it must equal the native launch colour
        // (flutter_native_splash `color` in pubspec.yaml), which cannot
        // follow the in-app theme.
        backgroundColor: AppColors.ink,
        body: CustomMultiChildLayout(
          delegate: _SplashLayout(safeArea: MediaQuery.paddingOf(context)),
          children: [
            LayoutId(
              id: _Slot.dove,
              child: SplashDove(trace: _trace, fill: _fill),
            ),
            LayoutId(
              id: _Slot.title,
              child: FadeTransition(
                opacity: _title,
                child: SlideTransition(
                  position: _title.drive(
                    Tween(begin: const Offset(0, 0.12), end: Offset.zero),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Kharis',
                          style: AppTypography.display(
                            size: 44,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Changing the world with a touch of His Grace',
                          textAlign: TextAlign.center,
                          style: AppTypography.serif(
                            size: 17,
                            italic: true,
                            height: 1.4,
                            color: dark.onBg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _Slot.actions,
              child: FadeTransition(
                opacity: _actions,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/role-selection'),
                          child: const Text('Get started'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Returning members sign in with their Kharis app
                      // account.
                      _SignInRow(onTap: () => context.go('/login')),
                      const SizedBox(height: 20),
                      Text(
                        'Establishing believers · Strengthening churches',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelMd.copyWith(
                          color: dark.muted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Slot { dove, title, actions }

/// Dove at the exact screen centre (where the native launch screen puts it),
/// wordmark and tagline below it, actions pinned to the bottom. If the text
/// would run into the actions (short phones, large text), the dove and text
/// move up together rather than overlap.
class _SplashLayout extends MultiChildLayoutDelegate {
  _SplashLayout({required this.safeArea});

  final EdgeInsets safeArea;

  static const double _doveToTitle = 20;
  static const double _minTitleToActions = 24;

  @override
  void performLayout(Size size) {
    final dove = layoutChild(_Slot.dove, BoxConstraints.tight(SplashDove.size));
    final width = BoxConstraints.tightFor(width: size.width);
    final title = layoutChild(_Slot.title, width);
    final actions = layoutChild(_Slot.actions, width);

    final actionsTop = size.height - actions.height;
    var doveTop = (size.height - dove.height) / 2;
    final overflow =
        doveTop +
        dove.height +
        _doveToTitle +
        title.height +
        _minTitleToActions -
        actionsTop;
    if (overflow > 0) {
      final room = doveTop - safeArea.top - AppSpacing.md;
      doveTop -= overflow.clamp(0, room > 0 ? room : 0);
    }

    positionChild(_Slot.dove, Offset((size.width - dove.width) / 2, doveTop));
    positionChild(_Slot.title, Offset(0, doveTop + dove.height + _doveToTitle));
    positionChild(_Slot.actions, Offset(0, actionsTop));
  }

  @override
  bool shouldRelayout(_SplashLayout oldDelegate) =>
      oldDelegate.safeArea != safeArea;
}

class _SignInRow extends StatelessWidget {
  const _SignInRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.buttonBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'I already have an account',
              style: AppTypography.ui(
                size: 15,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
