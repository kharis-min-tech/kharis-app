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

  Future<(FakeFirebaseFirestore, NewsItem)> seeded({
    String? eventId,
    String? linkUrl = 'https://kharis.org/choir',
  }) async {
    final db = FakeFirebaseFirestore();
    await db.collection('news').doc('n1').set({
      'title': 'Choir auditions',
      'type': 'Notice',
      'publishedAt': Timestamp.fromDate(_published),
      'expiresAt': Timestamp.fromDate(_expires),
      'eventId': eventId,
      'linkUrl': linkUrl,
      'ctaLabel': linkUrl == null ? null : 'Sign up',
    });
    final item = NewsItem(
      id: 'n1',
      title: 'Choir auditions',
      type: 'Notice',
      publishedAt: _published,
      expiresAt: _expires,
      eventId: eventId,
      linkUrl: linkUrl,
      ctaLabel: linkUrl == null ? null : 'Sign up',
    );
    return (db, item);
  }

  AnnouncementFormSheet sheetFor(FakeFirebaseFirestore db, NewsItem item) =>
      AnnouncementFormSheet(
        item: item,
        scopeBranch: 'London',
        repo: NewsRepository(firestore: db),
        onSuccess: (_) {},
        onError: (_) {},
      );

  testWidgets(
    'editing an all-campus announcement from a branch page keeps its scope, '
    'publish time, expiry and link',
    (tester) async {
      final (db, item) = await seeded();
      await _open(tester, sheetFor(db, item));

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
      expect(data['eventId'], isNull);
      expect(data['linkUrl'], 'https://kharis.org/choir');
      expect(data['ctaLabel'], 'Sign up');
    },
  );

  testWidgets('an event-linked announcement keeps its event', (tester) async {
    final (db, item) = await seeded(eventId: 'ev1', linkUrl: null);
    await _open(tester, sheetFor(db, item));

    expect(find.text('Harvest Sunday · Mon 12 Oct'), findsOneWidget);
    await _save(tester);

    final data = (await db.collection('news').doc('n1').get()).data()!;
    expect(data['eventId'], 'ev1');
    expect(data['linkUrl'], isNull);
  });

  testWidgets('a linked event and a button link together block the save', (
    tester,
  ) async {
    // Legacy data written before the two were exclusive.
    final (db, item) = await seeded(eventId: 'ev1');
    await _open(tester, sheetFor(db, item));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Choir auditions'),
      'Choir auditions this Sunday',
    );
    await _save(tester);

    expect(
      find.text('Choose a linked event or a button link, not both'),
      findsOneWidget,
    );
    final data = (await db.collection('news').doc('n1').get()).data()!;
    expect(data['title'], 'Choir auditions');
  });

  testWidgets('an upper-case scheme is stored lower-case', (tester) async {
    final (db, item) = await seeded();
    await _open(tester, sheetFor(db, item));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'https://kharis.org/choir'),
      ' HTTPS://kharis.org/Choir ',
    );
    await _save(tester);

    final data = (await db.collection('news').doc('n1').get()).data()!;
    expect(data['linkUrl'], 'https://kharis.org/Choir');
  });

  test('the stored link always matches the news rule', () {
    // Mirrors `linkUrl.matches(...)` in backend/firestore.rules.
    final rule = RegExp(r'^[Hh][Tt][Tt][Pp][Ss]?://.+$');
    for (final raw in ['HTTPS://a.org', 'Http://a.org/x', 'https://a.org']) {
      expect(validateAnnouncementLink(raw), isNull);
      final stored = normaliseAnnouncementLink(raw);
      expect(stored, matches(RegExp('^https?://')));
      expect(rule.hasMatch(stored), isTrue);
    }
    expect(normaliseAnnouncementLink(''), '');
  });

  testWidgets('a button link without http(s) blocks the save', (tester) async {
    final (db, item) = await seeded();
    await _open(tester, sheetFor(db, item));

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
