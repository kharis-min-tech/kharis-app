import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/presentation/widgets/event_form_sheet.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';

final _start = DateTime(2026, 10, 12, 18);
final _end = DateTime(2026, 10, 12, 20);
const _banner = 'https://kharis.org/banner.jpg';

/// Opens [sheet] the way the admin screens do: a modal bottom sheet.
Future<void> _open(
  WidgetTester tester,
  Widget sheet, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => sheet,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A loading spinner never settles; let the sheet animation finish.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'editing an all-campus event from a branch page keeps it all-campus and '
    'keeps its banner and featured flag',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('events').doc('e1').set({
        'title': 'Harvest Thanksgiving',
        'location': 'Main Hall',
        'startTime': Timestamp.fromDate(_start),
        'endTime': Timestamp.fromDate(_end),
        'imageUrl': _banner,
        'isFeatured': true,
      });
      final event = Event(
        id: 'e1',
        title: 'Harvest Thanksgiving',
        location: 'Main Hall',
        startTime: _start,
        endTime: _end,
        imageUrl: _banner,
        isFeatured: true,
      );

      await _open(
        tester,
        EventFormSheet(
          event: event,
          scopeBranch: 'London',
          eventRepo: EventRepository(firestore: db),
          onSuccess: (_) {},
          onError: (_) {},
        ),
      );

      // The branch page shows the event's own scope, not the page's campus.
      expect(find.text('All campuses'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Harvest Thanksgiving'),
        'Harvest Sunday',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Street, town, postcode',
        ),
        '1 High St, London',
      );
      final save = find.text('Save changes');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final data = (await db.collection('events').doc('e1').get()).data()!;
      expect(data['title'], 'Harvest Sunday');
      expect(data['address'], '1 High St, London');
      expect(data['branch'], isNull);
      expect(data['imageUrl'], _banner);
      expect(data['isFeatured'], isTrue);
      expect(find.byType(EventFormSheet), findsNothing);
    },
  );

  testWidgets('the Studio form keeps Save disabled while campuses load', (
    tester,
  ) async {
    final campuses = StreamController<List<Branch>>();
    addTearDown(campuses.close);
    await _open(
      tester,
      EventFormSheet(
        eventRepo: EventRepository(firestore: FakeFirebaseFirestore()),
        onSuccess: (_) {},
        onError: (_) {},
      ),
      overrides: [branchesProvider.overrideWith((ref) => campuses.stream)],
      settle: false,
    );

    expect(find.text('Loading campuses'), findsWidgets);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add event'),
    );
    expect(save.onPressed, isNull);
  });
}
