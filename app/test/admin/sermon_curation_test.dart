import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/presentation/screens/admin_sermons_screen.dart';
import 'package:kharis_app/features/admin/providers/content_config_providers.dart';
import 'package:kharis_app/features/home/data/reading_plan.dart'
    show readingDateKey;
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

final _library = [
  Sermon(
    id: '101',
    title: 'Older audio message',
    speaker: 'Pastor Ade',
    audioUrl: 'https://cdn.kharis.org/101.mp3',
    publishedAt: DateTime(2026, 8, 2),
  ),
  Sermon(
    id: '102',
    title: 'Newest audio message',
    speaker: 'Pastor Bola',
    audioUrl: 'https://cdn.kharis.org/102.mp3',
    publishedAt: DateTime(2026, 9, 27),
  ),
  Sermon(
    id: '103',
    title: 'Video only message',
    speaker: 'Pastor Ade',
    audioUrl: '',
    publishedAt: DateTime(2026, 9, 28),
  ),
];

Future<FakeFirebaseFirestore> _pumpScreen(
  WidgetTester tester, {
  Map<String, dynamic>? legacyMotd,
  List<Sermon>? library,
}) async {
  final db = FakeFirebaseFirestore();
  if (legacyMotd != null) {
    await db.collection('config').doc('messageOfTheDay').set(legacyMotd);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentConfigRepositoryProvider.overrideWithValue(
          ContentConfigRepository(firestore: db),
        ),
        adminSermonsProvider.overrideWith((ref) => Stream.value(const [])),
        sermonsProvider.overrideWith((ref) async => library ?? _library),
      ],
      child: const MaterialApp(home: AdminSermonsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Featured mode switches between Auto and Pinned', (tester) async {
    final db = await _pumpScreen(tester);
    expect(find.text('Stars only apply in Pinned mode.'), findsOneWidget);

    await tester.tap(find.text('Pinned'));
    await tester.pumpAndSettle();

    final doc = (await db.collection('config').doc('featured').get()).data()!;
    expect(doc['mode'], 'pinned');
    expect(find.text('Stars only apply in Pinned mode.'), findsNothing);
  });

  testWidgets(
    'choosing a message schedules it for today, newest audio first, and the '
    'X clears it',
    (tester) async {
      final db = await _pumpScreen(tester);
      final today = readingDateKey(DateTime.now());

      await tester.tap(find.text('Choose message'));
      await tester.pumpAndSettle();

      // Audio only, newest first.
      expect(find.text('Video only message'), findsNothing);
      final newest = tester.getTopLeft(find.text('Newest audio message'));
      final older = tester.getTopLeft(find.text('Older audio message'));
      expect(newest.dy, lessThan(older.dy));

      // Filters by speaker as you type.
      await tester.enterText(find.byType(TextField).last, 'ade');
      await tester.pumpAndSettle();
      expect(find.text('Newest audio message'), findsNothing);

      await tester.tap(find.text('Older audio message'));
      await tester.pumpAndSettle();

      final slot = (await db.collection('motdSchedule').doc(today).get())
          .data()!;
      expect(slot['sermonId'], '101');
      expect(slot['title'], 'Older audio message');
      expect(find.text('Older audio message'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('motdSchedule').doc(today).get()).exists,
        isFalse,
      );
    },
  );

  testWidgets('the offline catalogue (archive_ ids) can never be scheduled', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      library: [
        ..._library,
        Sermon(
          id: 'archive_12',
          title: 'Bundled archive message',
          speaker: 'Pastor Ade',
          audioUrl: 'https://cdn.kharis.org/archive/12.mp3',
          publishedAt: DateTime(2026, 9, 30),
          source: 'archive',
        ),
      ],
    );

    await tester.tap(find.text('Choose message'));
    await tester.pumpAndSettle();

    expect(find.text('Bundled archive message'), findsNothing);
    expect(find.text('Newest audio message'), findsOneWidget);
    expect(
      find.textContaining('sermon library is offline'),
      findsOneWidget,
      reason: 'the admin learns why archive messages are missing',
    );
  });

  testWidgets('the legacy Message of the Day is moved into today on open', (
    tester,
  ) async {
    final db = await _pumpScreen(
      tester,
      legacyMotd: {'sermonId': '102', 'title': 'Newest audio message'},
    );

    expect(
      find.text('Moved the old Message of the Day into today’s schedule'),
      findsOneWidget,
    );
    final today = readingDateKey(DateTime.now());
    final slot = (await db.collection('motdSchedule').doc(today).get()).data()!;
    expect(slot['sermonId'], '102');
    expect(
      (await db.collection('config').doc('messageOfTheDay').get()).exists,
      isFalse,
    );
  });
}
