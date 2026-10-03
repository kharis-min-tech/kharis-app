import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/presentation/widgets/announcement_form_sheet.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// Publish in the past, expiry in the future at a time that is NOT a London
// end-of-day, so a save that re-derived either would be caught.
final _published = DateTime.utc(2026, 9, 20, 8, 30);
final _expires = DateTime.utc(2099, 3, 4, 15, 45);

final _upcoming = Event(
  id: 'ev1',
  title: 'Harvest Sunday',
  startTime: DateTime(2099, 10, 12, 10),
);

Future<void> _open(WidgetTester tester, Widget sheet) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        upcomingEventsProvider.overrideWith(
          (ref, branch) => Stream.value([_upcoming]),
        ),
      ],
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
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.text('Save changes');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(FakeFirebaseFirestore, NewsItem)> seeded() async {
    final db = FakeFirebaseFirestore();
    await db.collection('news').doc('n1').set({
      'title': 'Choir auditions',
      'type': 'Notice',
      'publishedAt': Timestamp.fromDate(_published),
      'expiresAt': Timestamp.fromDate(_expires),
      'eventId': 'ev1',
      'linkUrl': 'https://kharis.org/choir',
      'ctaLabel': 'Sign up',
    });
    final item = NewsItem(
      id: 'n1',
      title: 'Choir auditions',
      type: 'Notice',
      publishedAt: _published,
      expiresAt: _expires,
      eventId: 'ev1',
      linkUrl: 'https://kharis.org/choir',
      ctaLabel: 'Sign up',
    );
    return (db, item);
  }

  testWidgets(
    'editing an all-campus announcement from a branch page keeps its scope, '
    'publish time, expiry and link',
    (tester) async {
      final (db, item) = await seeded();
      await _open(
        tester,
        AnnouncementFormSheet(
          item: item,
          scopeBranch: 'London',
          repo: NewsRepository(firestore: db),
          onSuccess: (_) {},
          onError: (_) {},
        ),
      );

      expect(find.text('Harvest Sunday · Mon 12 Oct'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Choir auditions'),
        'Choir auditions this Sunday',
      );
      await _save(tester);

      final data = (await db.collection('news').doc('n1').get()).data()!;
      expect(data['title'], 'Choir auditions this Sunday');
      expect(data['branch'], isNull);
      expect((data['publishedAt'] as Timestamp).toDate().toUtc(), _published);
      expect((data['expiresAt'] as Timestamp).toDate().toUtc(), _expires);
      expect(data['eventId'], 'ev1');
      expect(data['linkUrl'], 'https://kharis.org/choir');
      expect(data['ctaLabel'], 'Sign up');
    },
  );

  testWidgets('a button link without http(s) blocks the save', (tester) async {
    final (db, item) = await seeded();
    await _open(
      tester,
      AnnouncementFormSheet(
        item: item,
        scopeBranch: 'London',
        repo: NewsRepository(firestore: db),
        onSuccess: (_) {},
        onError: (_) {},
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'https://kharis.org/choir'),
      'kharis.org/choir',
    );
    await _save(tester);

    expect(
      find.text('Links must start with http:// or https://'),
      findsOneWidget,
    );
    final data = (await db.collection('news').doc('n1').get()).data()!;
    expect(data['linkUrl'], 'https://kharis.org/choir');
  });
}
