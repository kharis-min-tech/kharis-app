import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/configs/app_startup.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/alert_dialog.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/splash_dove.dart';
import 'package:kharis_app/shared/models/remote_config.dart';

/// Splash / brand entry.
///
/// Solid ink, the dove centred exactly where the native launch screen draws
/// it. The dove's outline draws itself in and fills, the "Kharis" wordmark
/// and tagline fade up beneath it, then the **Get started** button and the
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
  void initState() {
    super.initState();
    performUpdateChecksAndNavigate();
  }

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

  void performUpdateChecksAndNavigate() {
    // check for update
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (getIt.isRegistered<RemoteConfigModel>()) {
        RemoteConfigModel config = getIt<RemoteConfigModel>();
        if (config.remoteBuildNumber != null &&
            config.localBuildNumber != null &&
            config.remoteBuildNumber! > config.localBuildNumber!) {
          showPlatformAlertDialogAdaptive(
            context,
            description: config.forceUpdate!
                ? "You're using an older version of the app that is no longer supported.\nPlease update to the latest version to continue enjoying our services."
                : "A new version of the app is available with improvements and bug fixes to make your experience even better.\n\nUpdate now to enjoy the latest features.",
            title: config.forceUpdate!
                ? "Update required"
                : "App update available",
            forceUpdate: config.forceUpdate!,
            onOk: () {
              //Navigate to appstore Url
            },
            cancelText: "Later",
            okText: config.forceUpdate! ? "Update now" : "Update",
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // The launch screen is dark in both modes, so this screen sits on
        // the ink role and its text on onInk.
        backgroundColor: k.ink,
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
                      horizontal: KSpace.gutter,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Kharis',
                          style: KharisText.screenTitle.copyWith(
                            color: k.onInk,
                          ),
                        ),
                        const SizedBox(height: KSpace.md),
                        Text(
                          'Changing the world with a touch of His Grace',
                          textAlign: TextAlign.center,
                          style: KharisText.body.copyWith(color: k.onInk),
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
                    KSpace.gutter,
                    0,
                    KSpace.gutter,
                    KSpace.gutter + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: KSize.maxContentWidth,
                        ),
                        child: KButton(
                          label: 'Get started',
                          size: KButtonSize.cta,
                          expand: true,
                          onPressed: () => context.go('/role-selection'),
                        ),
                      ),
                      const SizedBox(height: KSpace.md),
                      // Returning members sign in with their Kharis app
                      // account.
                      _SignInRow(onTap: () => context.go('/login')),
                      const SizedBox(height: KSpace.x3),
                      Text(
                        'Establishing believers · Strengthening churches',
                        textAlign: TextAlign.center,
                        style: KharisText.caption.copyWith(color: k.onInk),
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

  static const double _doveToTitle = KSpace.gutter;
  static const double _minTitleToActions = KSpace.section;

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
      final room = doveTop - safeArea.top - KSpace.gutter;
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
    final onInk = context.k.onInk;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSize.touchMin),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KIcon(KIcons.lock, size: KSize.iconMd, color: onInk),
              const SizedBox(width: KSpace.md),
              Flexible(
                child: Text(
                  'I already have an account',
                  style: KharisText.link.copyWith(color: onInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
