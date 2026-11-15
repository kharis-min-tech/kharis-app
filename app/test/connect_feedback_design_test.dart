import 'package:dio/dio.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/supabase_stub.dart';

/// Light and dark, at 100% and 130% text size.
const _variants = [
  (dark: false, scale: 1.0),
  (dark: false, scale: 1.3),
  (dark: true, scale: 1.0),
  (dark: true, scale: 1.3),
];

String _name(({bool dark, double scale}) v) =>
    '${v.dark ? 'dark' : 'light'} at ${(v.scale * 100).round()}%';

final _branch = Branch(
  id: 'london',
  name: 'London',
  subtitle: '',
  gradientStart: KBrand.purple,
  gradientEnd: KBrand.purple,
);

/// [home] in the new theme on a 390-wide phone.
Future<void> _pump(
  WidgetTester tester,
  ({bool dark, double scale}) v, {
  required List<Override> overrides,
  required Widget home,
}) async {
  tester.view.physicalSize = const Size(KSize.designWidth, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: KharisTheme.light(),
        darkTheme: KharisTheme.dark(),
        themeMode: v.dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(v.scale)),
          child: app!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(
  WidgetTester tester,
  ({bool dark, double scale}) v,
  Widget screen, {
  bool offline = false,
}) {
  final stub = SupabaseStub({'testimonies': [], 'visitors': []})
    ..offline = offline;
  return _pump(
    tester,
    v,
    overrides: [
      branchesProvider.overrideWith((ref) => Stream.value([_branch])),
      connectRepositoryProvider.overrideWithValue(
        ConnectRepository(dio: Dio()..httpClientAdapter = stub),
      ),
    ],
    home: screen,
  );
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextFormField),
);

Future<void> _choose(WidgetTester tester, String hint, String item) async {
  await tester.ensureVisible(find.text(hint));
  await tester.pumpAndSettle();
  // The hint sits under the dropdown's own tap target.
  await tester.tap(find.text(hint), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadDesignAssets);

  group('New here form', () {
    for (final v in _variants) {
      testWidgets('empty, with errors and sent: ${_name(v)}', (tester) async {
        await _pumpForm(tester, v, const NewHereScreen());
        expect(find.text('New here?'), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        expect(tester.takeException(), isNull);

        await _tapText(tester, 'Connect with us');
        expect(find.text('Name is required'), findsOneWidget);
        expect(find.text('Email is required'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.enterText(_field('Full name *'), 'Ada');
        await tester.enterText(_field('Email address *'), 'ada@example.com');
        await _choose(tester, 'Choose your branch', 'London');
        await _tapText(tester, 'Connect with us');
        expect(find.text('Welcome to Kharis'), findsOneWidget);
        expect(find.widgetWithText(KButton, 'Done'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a failed send says so on the form', (tester) async {
      await _pumpForm(
        tester,
        _variants.last,
        const NewHereScreen(),
        offline: true,
      );
      await tester.enterText(_field('Full name *'), 'Ada');
      await tester.enterText(_field('Email address *'), 'ada@example.com');
      await _tapText(tester, 'Connect with us');
      expect(
        find.widgetWithText(
          KInlineError,
          'Your details were not sent. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Welcome to Kharis'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the visit date opens the date picker', (tester) async {
      await _pumpForm(tester, _variants.first, const NewHereScreen());
      await tester.ensureVisible(_field('First visit date'));
      await tester.tap(_field('First visit date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Testimony form', () {
    const consent = 'I am happy for Kharis to share my testimony';

    for (final v in _variants) {
      testWidgets('empty, with errors and sent: ${_name(v)}', (tester) async {
        await _pumpForm(tester, v, const TestimonyScreen());
        expect(find.text('Share your testimony'), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        expect(tester.takeException(), isNull);

        await _tapText(tester, 'Share testimony');
        expect(find.text('Name is required'), findsOneWidget);
        expect(find.text('Branch is required'), findsOneWidget);
        expect(
          find.text('Please confirm we may share your testimony'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.enterText(_field('Full name *'), 'Ada');
        await tester.enterText(_field('Short title / summary *'), 'Healed');
        await tester.enterText(_field('Your testimony *'), 'God healed me.');
        await _choose(tester, 'Choose your branch', 'London');
        await _tapText(tester, 'Share anonymously');
        await _tapText(tester, consent);
        expect(tester.takeException(), isNull);
        await _tapText(tester, 'Share testimony');
        expect(find.text('Thank you for sharing'), findsOneWidget);
        expect(find.widgetWithText(KButton, 'Done'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the switch and the consent tick say their state', (
      tester,
    ) async {
      await _pumpForm(tester, _variants.first, const TestimonyScreen());
      final handle = tester.ensureSemantics();
      await tester.ensureVisible(find.text(consent));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Share anonymously')),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      expect(
        tester.getSemantics(find.text(consent)),
        isSemantics(hasCheckedState: true, isChecked: false),
      );

      await _tapText(tester, 'Share anonymously');
      await _tapText(tester, consent);
      expect(
        tester.getSemantics(find.text('Share anonymously')),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      expect(
        tester.getSemantics(find.text(consent)),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      handle.dispose();
    });
  });

  group('Feedback sheet', () {
    Future<void> open(
      WidgetTester tester,
      ({bool dark, double scale}) v,
      FeedbackSource source,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await _pump(
        tester,
        v,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          currentUserProvider.overrideWith(
            (ref) => Stream.value(
              User(
                id: 'member-1',
                email: '',
                displayName: 'Guest',
                role: 'guest',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => KButton(
              label: 'Open',
              onPressed: () => showFeedbackSheet(context, ref, source: source),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    for (final v in _variants) {
      for (final source in FeedbackSource.values) {
        testWidgets('unrated, rated and sent from ${source.name}: '
            '${_name(v)}', (tester) async {
          await open(tester, v, source);
          expect(
            find.text('How is the Kharis app serving you?'),
            findsOneWidget,
          );
          expect(find.text('Tap a star to rate'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(const ValueKey('feedback-star-3')));
          await tester.pumpAndSettle();
          expect(find.text('It’s okay'), findsOneWidget);
          expect(find.byKey(const ValueKey('feedback-comment')), findsOne);
          expect(tester.takeException(), isNull);

          await tester.tap(find.widgetWithText(KButton, 'Send feedback'));
          await tester.pumpAndSettle();
          expect(find.text('Thank you'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the close button closes the sheet', (tester) async {
      await open(tester, _variants.first, FeedbackSource.settings);
      final handle = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Close feedback'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackSheet), findsNothing);
      handle.dispose();
    });
  });
}
