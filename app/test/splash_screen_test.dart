import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/splash_dove.dart';

const _tagline = 'Changing the world with a touch of His Grace';
const _signIn = 'I already have an account';

/// Pumps the splash at an iPhone 15 size (393x852 pt), with stub screens on
/// the two routes it leads to.
Future<void> _pumpSplash(
  WidgetTester tester, {
  bool reduceMotion = false,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      for (final path in ['/role-selection', '/login'])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('route:$path')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: kharisTheme(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
}

/// What a viewer sees of [finder]: the product of every fade above it.
double _opacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final fade in tester.widgetList<FadeTransition>(
    find.ancestor(of: finder, matching: find.byType(FadeTransition)),
  )) {
    opacity *= fade.opacity.value;
  }
  return opacity;
}

Finder get _doveImage => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == AppAssets.splashDove,
);

void _expectFinalState(WidgetTester tester) {
  for (final finder in [
    _doveImage,
    find.text('Kharis'),
    find.text(_tagline),
    find.text('Get started'),
    find.text(_signIn),
  ]) {
    expect(finder, findsOneWidget);
    expect(_opacity(tester, finder), 1, reason: '$finder fully visible');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('opens on the faint launch dove with nothing else shown', (
    tester,
  ) async {
    await _pumpSplash(tester);

    expect(_opacity(tester, _doveImage), SplashDove.launchOpacity);
    expect(_opacity(tester, find.text('Kharis')), 0);
    expect(_opacity(tester, find.text('Get started')), 0);
    expect(_opacity(tester, find.text(_signIn)), 0);
  });

  testWidgets('mid-animation: dove still tracing, CTA not yet shown', (
    tester,
  ) async {
    await _pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(_opacity(tester, _doveImage), SplashDove.launchOpacity);
    expect(_opacity(tester, find.text('Get started')), 0);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('settles on dove, wordmark, tagline, CTA and sign-in row', (
    tester,
  ) async {
    await _pumpSplash(tester);
    await tester.pumpAndSettle();

    _expectFinalState(tester);
  });

  testWidgets('with reduce motion the final state is the first frame', (
    tester,
  ) async {
    await _pumpSplash(tester, reduceMotion: true);

    _expectFinalState(tester);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('dove sits at the screen centre, as on the launch screen', (
    tester,
  ) async {
    await _pumpSplash(tester, reduceMotion: true);

    expect(tester.getSize(find.byType(SplashDove)), SplashDove.size);
    expect(tester.getCenter(find.byType(SplashDove)), const Offset(196.5, 426));
  });

  testWidgets('on a short phone the text clears the actions', (tester) async {
    await _pumpSplash(tester, reduceMotion: true, size: const Size(320, 568));

    final taglineBottom = tester.getBottomLeft(find.text(_tagline)).dy;
    final ctaTop = tester.getTopLeft(find.byType(ElevatedButton)).dy;
    expect(taglineBottom, lessThan(ctaTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Get started opens role selection', (tester) async {
    await _pumpSplash(tester, reduceMotion: true);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('route:/role-selection'), findsOneWidget);
  });

  testWidgets('I already have an account opens sign in', (tester) async {
    await _pumpSplash(tester, reduceMotion: true);
    await tester.tap(find.text(_signIn));
    await tester.pumpAndSettle();
    expect(find.text('route:/login'), findsOneWidget);
  });
}
