import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_sermon_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final live = [
    for (var i = 1; i <= 3; i++)
      testSermon(
        '$i',
        title: 'Live message $i',
        publishedAt: DateTime(2026, 9, i),
      ),
  ];

  Widget app(
    FakePagedSermonRepository repo, {
    Duration? debounce,
  }) => ProviderScope(
    overrides: [
      sermonRepositoryProvider.overrideWithValue(repo),
      sermonArchiveAutoHydrateProvider.overrideWithValue(false),
      cmsSermonsProvider.overrideWith((ref) => Stream.value(const <Sermon>[])),
      videosProvider.overrideWith((ref) async => const <Sermon>[]),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      cacheServiceProvider.overrideWithValue(FakeCacheService()),
      audioPlayerServiceProvider.overrideWithValue(FakeAudioPlayerService()),
      if (debounce != null) searchDebounceProvider.overrideWithValue(debounce),
    ],
    child: const MaterialApp(home: MessagesScreen()),
  );

  testWidgets('offline fallback shows a banner whose Retry goes live', (
    tester,
  ) async {
    final repo = FakePagedSermonRepository(
      [live],
      failFirstLoad: true,
      catalogue: [testSermon('archive_1', title: 'Bundled message')],
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Offline archive'), findsOneWidget);
    expect(find.text('Bundled message'), findsOneWidget);

    repo.failFirstLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Offline archive'), findsNothing);
    expect(find.text('Live message 3'), findsWidgets);
    expect(find.text('Bundled message'), findsNothing);
  });

  testWidgets('pull to refresh refetches page 1', (tester) async {
    final repo = FakePagedSermonRepository([live]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(repo.requested.where((u) => u == null), hasLength(1));

    await tester.fling(find.text('Messages').first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.requested.where((u) => u == null), hasLength(2));
    expect(find.text('Live message 3'), findsWidgets);
  });

  testWidgets('search shows a spinner while loading, never "no results"', (
    tester,
  ) async {
    final repo = FakePagedSermonRepository(
      [live],
      searchPages: {
        'zebra': [
          [testSermon('99', title: 'Zebra on the server')],
        ],
      },
    );
    await tester.pumpWidget(
      app(repo, debounce: const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.textContaining('No messages match'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Zebra on the server'), findsOneWidget);
    expect(find.textContaining('No messages match'), findsNothing);
  });

  testWidgets('recent searches appear on focus and refill the field', (
    tester,
  ) async {
    final repo = FakePagedSermonRepository([live]);
    await tester.pumpWidget(app(repo, debounce: Duration.zero));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Live message 2');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);

    await tester.tap(find.text('Live message 2').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 result for'), findsOneWidget);
  });
}
