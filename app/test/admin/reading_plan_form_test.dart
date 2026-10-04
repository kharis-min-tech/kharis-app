import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/presentation/widgets/reading_plan_form_sheet.dart';
import 'package:kharis_app/features/home/data/reading_plan_repository.dart';

ReadingPlan _plan({
  String book = '2 Corinthians',
  int startChapter = 1,
  int days = 20,
  ReadingPlanMode mode = ReadingPlanMode.chapter,
}) => ReadingPlan(
  id: '',
  title: '',
  book: book,
  startDate: DateTime(2026, 10, 3),
  days: days,
  startChapter: startChapter,
  mode: mode,
);

const _capHint = 'Max 13 days: 2 Corinthians has 13 chapters from chapter 1';

String? _daysError(WidgetTester tester) =>
    tester.widget<TextField>(_daysField()).decoration?.errorText;

Future<void> _openSheet(
  WidgetTester tester, {
  required ReadingPlan plan,
  required ReadingPlanRepository repo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ReadingPlanFormSheet(
                plan: plan,
                existing: const [],
                repo: repo,
                onSuccess: (_) {},
                onError: (_) {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _daysField() => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == '31',
);

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.text('Save plan');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('chapter-mode cap', () {
    test('2 Corinthians from chapter 1 allows at most 13 days', () {
      final plan = _plan();
      expect(planMaxDays(plan), 13);
      expect(planDaysCapHint(plan), _capHint);
      expect(validatePlanDays('20', plan), _capHint);
      expect(validatePlanDays('13', plan), isNull);
    });

    test('the cap follows the start chapter', () {
      final plan = _plan(startChapter: 10, days: 4);
      expect(planMaxDays(plan), 4);
      expect(validatePlanDays('5', plan), isNotNull);
      expect(validatePlanDays('4', plan), isNull);
    });

    test('verse mode is not capped by the book', () {
      final plan = _plan(mode: ReadingPlanMode.verse, days: 40);
      expect(planMaxDays(plan), isNull);
      expect(planDaysCapHint(plan), isNull);
      expect(validatePlanDays('40', plan), isNull);
    });
  });

  testWidgets(
    'a 2 Corinthians plan from chapter 1 cannot be saved with 20 days and '
    'shows a max of 13',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final repo = ReadingPlanRepository(firestore: db);
      await _openSheet(tester, plan: _plan(), repo: repo);
      // Over the cap: the max is shown as the field's error.
      expect(find.text(_capHint), findsOneWidget);
      expect(_daysError(tester), _capHint);

      await _tapSave(tester);
      expect((await db.collection('readingPlans').get()).docs, isEmpty);
      expect(find.byType(ReadingPlanFormSheet), findsOneWidget);

      await tester.enterText(_daysField(), '13');
      await tester.pumpAndSettle();
      expect(_daysError(tester), isNull);
      // At the cap: the same line stays as a helper.
      expect(find.text(_capHint), findsOneWidget);
      expect(
        find.text('Last reading: 2 Corinthians 13 on Oct 15, 2026'),
        findsOneWidget,
      );

      await _tapSave(tester);
      final docs = (await db.collection('readingPlans').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['days'], 13);
    },
  );

  testWidgets('switching to chapter mode clamps days to the book', (
    tester,
  ) async {
    final repo = ReadingPlanRepository(firestore: FakeFirebaseFirestore());
    await _openSheet(
      tester,
      plan: _plan(mode: ReadingPlanMode.verse, days: 40),
      repo: repo,
    );
    expect(find.text(_capHint), findsNothing);

    await tester.tap(find.text('A chapter a day'));
    await tester.pumpAndSettle();

    final days = tester.widget<TextField>(_daysField());
    expect(days.controller!.text, '13');
    expect(find.text(_capHint), findsOneWidget);
  });
}
