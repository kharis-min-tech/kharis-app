// Layout checks for the entry screens (splash, role selection, branch
// selection, sign in, register), the branch picker sheet and the
// notification card: each is built at the 390 design width in light and dark
// at 100% and 130% text size and must lay out with no overflow or error.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/login_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/register_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/location_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/shared/widgets/notification_permission_card.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/fake_location_service.dart';

const _phone = Size(KSize.designWidth, 844);

Branch _branch(
  String name,
  String subtitle, {
  String group = Branch.mainGroup,
}) => Branch(
  id: name.toLowerCase(),
  name: name,
  subtitle: subtitle,
  group: group,
  gradientStart: const Color(0xFF5D3FD3),
  gradientEnd: const Color(0xFF451EBB),
);

final _branches = [
  _branch('London', 'England · Main branch'),
  _branch('Manchester', 'England'),
  _branch('Bristol', 'England'),
  _branch(
    'KP2 Accra',
    'Ghana · A long region line that must wrap or cut cleanly',
    group: Branch.phaseTwoGroup,
  ),
];

class _QuietNotifications extends NotificationService {
  @override
  Future<void> switchBranchTopic({String? from, String? to}) async {}
}

/// Pumps [home] as a full screen on a 390 x 844 phone.
Future<void> _pumpScreen(
  WidgetTester tester,
  Widget home, {
  required bool dark,
  required double textScale,
  List<Branch>? branches,
  String? currentBranch,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'onboarding_branch': ?currentBranch});
  final prefs = await SharedPreferences.getInstance();
  // The screens navigate with go_router, so they need one above them.
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => home)],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        branchesProvider.overrideWith(
          (ref) => Stream.value(branches ?? _branches),
        ),
        notificationServiceProvider.overrideWithValue(_QuietNotifications()),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: KharisTheme.light(),
        darkTheme: KharisTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: app!,
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _forEachMode(
  String name,
  Future<void> Function(WidgetTester tester, bool dark, double scale) body,
) {
  for (final dark in const [false, true]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
        '$name · ${dark ? 'dark' : 'light'} · ${(scale * 100).round()}%',
        (tester) async {
          await body(tester, dark, scale);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void main() {
  setUpAll(loadDesignAssets);

  _forEachMode('splash', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const SplashScreen(),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.byType(KButton), findsOneWidget);
    // The launch screen is dark in both modes.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final theme = dark ? KharisTheme.dark() : KharisTheme.light();
    expect(scaffold.backgroundColor, theme.extension<KharisColors>()!.ink);
  });

  _forEachMode('role selection', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const RoleSelectionScreen(),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Welcome home'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
  });

  _forEachMode('branch selection', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const BranchSelectionScreen(),
      dark: dark,
      textScale: scale,
      currentBranch: 'Manchester',
    );
    expect(find.text('Find your branch'), findsOneWidget);
    expect(find.byKey(const ValueKey('branch-use-location')), findsOneWidget);
    expect(find.byType(BranchTile), findsNWidgets(_branches.length));
  });

  _forEachMode('branch selection, loading', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const BranchSelectionScreen(),
      dark: dark,
      textScale: scale,
      branches: const [],
    );
    expect(find.byType(KErrorState), findsOneWidget);
  });

  _forEachMode('sign in with errors', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const LoginScreen(),
      dark: dark,
      textScale: scale,
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  _forEachMode('reset password sheet', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const LoginScreen(),
      dark: dark,
      textScale: scale,
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsWidgets);
  });

  _forEachMode('register with errors', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const RegisterScreen(),
      dark: dark,
      textScale: scale,
    );
    await tester.ensureVisible(find.byType(KButton));
    await tester.tap(find.byType(KButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);
  });

  _forEachMode('branch picker sheet', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: KButton(
              label: 'Open',
              onPressed: () =>
                  showBranchPicker(context, current: 'London', allowAll: true),
            ),
          ),
        ),
      ),
      dark: dark,
      textScale: scale,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(kChooseBranchLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('branch-use-location')), findsOneWidget);
    expect(find.byKey(const ValueKey('branch-choice-all')), findsOneWidget);
    // The current branch is marked with a check, not colour alone.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('branch-choice-London')),
        matching: find.byType(KIcon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('branch-choice-Bristol')),
        matching: find.byType(KIcon),
      ),
      findsNothing,
    );
  });

  _forEachMode('notification card', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(KSpace.gutter),
          child: NotificationPermissionCard(
            permission: NotificationPermission.askable,
            message:
                'Turn them on to hear about services, events and new '
                'messages from your branch.',
            onPreferences: () {},
            onNotNow: () {},
          ),
        ),
      ),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Turn on notifications'), findsOneWidget);
    expect(find.text('Choose what you get'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.byType(KButton), findsOneWidget);
  });
}
