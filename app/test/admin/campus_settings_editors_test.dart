import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/data/branch_settings_repository.dart';
import 'package:kharis_app/features/admin/presentation/screens/admin_app_settings_screen.dart';
import 'package:kharis_app/features/admin/presentation/widgets/giving_editor.dart';
import 'package:kharis_app/features/admin/presentation/widgets/home_layout_editor.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';

/// A tall surface so a whole editor lays out on screen.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  _tallView(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeFirebaseFirestore db;
  late BranchSettingsRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = BranchSettingsRepository(firestore: db);
    await db.collection('branches').doc('london').set({
      'name': 'London',
      'order': 1,
      'group': 'Kharis',
      'isActive': true,
    });
  });

  Future<Map<String, dynamic>> branch() async =>
      (await db.collection('branches').doc('london').get()).data()!;

  group('Home layout editor', () {
    testWidgets('writes home.sections in the arranged order with toggles', (
      tester,
    ) async {
      await _pump(
        tester,
        HomeLayoutEditor(
          initial: null,
          inherited: HomeLayout.fallback,
          inheritedHint: 'Using the church-wide default.',
          clearLabel: 'Use church-wide default',
          onSave: (home) => repo.setHome('london', home),
        ),
      );

      // Giving above Continue listening, then to the very top; switch it on
      // and switch Live off.
      await _tapVisible(tester, find.byTooltip('Move Giving up'));
      for (var i = 0; i < 6; i++) {
        await _tapVisible(tester, find.byTooltip('Move Giving up'));
      }
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('home-switch-giving')),
      );
      await _tapVisible(tester, find.byKey(const ValueKey('home-switch-live')));
      await _tapVisible(tester, find.text('Save Home layout'));

      final data = await branch();
      expect(data['home'], {
        'sections': [
          {'id': 'giving', 'enabled': true},
          {'id': 'profileCompletion', 'enabled': true},
          {'id': 'live', 'enabled': false},
          {'id': 'reading', 'enabled': true},
          {'id': 'announcements', 'enabled': true},
          {'id': 'events', 'enabled': true},
          {'id': 'campus', 'enabled': true},
          {'id': 'continueListening', 'enabled': true},
        ],
      });
      // Identity fields are never part of the write.
      expect(data['name'], 'London');
      expect(data['order'], 1);
      expect(data['group'], 'Kharis');
      expect(data['isActive'], isTrue);
    });

    testWidgets('"Use church-wide default" clears home', (tester) async {
      await db.collection('branches').doc('london').update({
        'home': HomeLayout.fallback.toJson(),
      });
      await _pump(
        tester,
        HomeLayoutEditor(
          initial: HomeLayout.fallback,
          inherited: HomeLayout.fallback,
          inheritedHint: 'Using the church-wide default.',
          clearLabel: 'Use church-wide default',
          onSave: (home) => repo.setHome('london', home),
        ),
      );

      await _tapVisible(tester, find.text('Use church-wide default'));
      expect((await branch()).containsKey('home'), isFalse);
    });
  });

  group('Giving editor', () {
    testWidgets('saves every field, international ones included', (
      tester,
    ) async {
      await _pump(
        tester,
        GivingEditor(
          initial: null,
          clearLabel: 'Use church-wide giving',
          fallbackHint: 'Not set.',
          onSave: (g) => repo.setGiving('london', g),
        ),
      );

      Future<void> type(String key, String text) async {
        final f = find.byKey(ValueKey('giving-$key'));
        await tester.ensureVisible(f);
        await tester.enterText(f, text);
      }

      await type('url', 'https://give.kharis.org/london');
      await type('accountName', 'Kharis London');
      await type('accountNumber', '12345678');
      await type('sortCode', '20-00-00');
      await type('swiftBic', 'BARCGB22');
      await type('iban', 'GB00BARC20000012345678');
      await type('reference', 'LONDON TITHE');
      await _tapVisible(tester, find.text('Save giving details'));

      expect((await branch())['giving'], {
        'url': 'https://give.kharis.org/london',
        'accountName': 'Kharis London',
        'sortCode': '20-00-00',
        'accountNumber': '12345678',
        'swiftBic': 'BARCGB22',
        'iban': 'GB00BARC20000012345678',
        'reference': 'LONDON TITHE',
      });
    });

    testWidgets('bank details without an account number are refused', (
      tester,
    ) async {
      await _pump(
        tester,
        GivingEditor(
          initial: null,
          clearLabel: 'Use church-wide giving',
          fallbackHint: 'Not set.',
          onSave: (g) => repo.setGiving('london', g),
        ),
      );
      final name = find.byKey(const ValueKey('giving-accountName'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Kharis London');
      await _tapVisible(tester, find.text('Save giving details'));

      expect(find.text('Needed for bank transfers'), findsOneWidget);
      expect((await branch()).containsKey('giving'), isFalse);
    });

    testWidgets('"Use church-wide giving" clears the campus giving', (
      tester,
    ) async {
      const own = GivingDetails(
        url: 'https://give.kharis.org/london',
        accountName: 'Kharis London',
        accountNumber: '12345678',
      );
      await db.collection('branches').doc('london').update({
        'giving': own.toJson(),
      });
      await _pump(
        tester,
        GivingEditor(
          initial: own,
          clearLabel: 'Use church-wide giving',
          fallbackHint: 'Not set.',
          onSave: (g) => repo.setGiving('london', g),
        ),
      );

      await _tapVisible(tester, find.text('Use church-wide giving'));
      final data = await branch();
      expect(data.containsKey('giving'), isFalse);
      expect(data['name'], 'London');
    });
  });

  testWidgets('App settings writes church-wide giving and Home to config', (
    tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AdminAppSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final url = find.byKey(const ValueKey('giving-url'));
    await tester.ensureVisible(url);
    await tester.enterText(url, 'https://give.kharis.org');
    await _tapVisible(tester, find.text('Save giving details'));
    expect((await db.collection('config').doc('giving').get()).data(), {
      'url': 'https://give.kharis.org',
    });

    await _tapVisible(tester, find.byKey(const ValueKey('home-switch-giving')));
    await _tapVisible(tester, find.text('Save Home layout'));
    final home = HomeLayout.fromJson(
      (await db.collection('config').doc('home').get()).data(),
    );
    expect(home?.visible.last, HomeSectionId.giving);
  });
}
