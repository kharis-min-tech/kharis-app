// Goldens for the Bible screens: the landing screen and the reader on
// today's reading, in light and dark, at the 390 design width. Regenerate
// after an intended visual change:
//
//     flutter test --no-pub --update-goldens test/design_bible_screens_goldens_test.dart
//
// As in design_component_goldens_test.dart, pixels are compared on macOS
// only; elsewhere each screen is still built, which catches overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/bible/presentation/screens/bible_screen.dart';
import 'package:kharis_app/features/bible/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/last_read_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/design_harness.dart';
import 'support/fake_cache_service.dart';

const _words = [
  'In the beginning was the Word, and the Word was with God, and the Word '
      'was God.',
  'The same was in the beginning with God.',
  'All things were made by him; and without him was not any thing made '
      'that was made.',
  'In him was life; and the life was the light of men.',
  'And the light shineth in darkness; and the darkness comprehended it not.',
  'There was a man sent from God, whose name was John.',
];

class _Bible extends BibleRepository {
  _Bible() : super(appKey: 'test');

  @override
  Future<List<BibleVersion>> getBibles() async => const [
    BibleVersion(id: 1, abbreviation: 'KJV', title: 'King James Version'),
  ];

  @override
  Future<List<BibleBook>> getBooks(int bibleId) async =>
      BibleIndex.bundled().books;

  @override
  Future<BiblePassage> getPassage(
    String usfmId, {
    int bibleId = BibleRepository.defaultBibleId,
    String abbreviation = BibleRepository.defaultBibleAbbreviation,
  }) async => BiblePassage(
    reference: usfmId,
    bibleAbbreviation: abbreviation,
    blocks: [
      PassageBlock(
        styleClass: 'p',
        segments: [
          for (final (i, text) in _words.indexed)
            PassageSegment(verse: i + 1, text: text),
        ],
      ),
    ],
  );
}

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({
    SelectedBibleController.idKey: 1,
    SelectedBibleController.abbreviationKey: 'KJV',
    SelectedBibleController.titleKey: 'King James Version',
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      cacheServiceProvider.overrideWithValue(FakeCacheService()),
      bibleRepositoryProvider.overrideWithValue(_Bible()),
      todayProvider.overrideWithValue(DateTime(2026, 11, 13)),
      sermonsProvider.overrideWith(
        (ref) async => const [
          Sermon(
            id: 'm1',
            title: 'The Word made flesh',
            speaker: 'Pastor David',
            audioUrl: 'https://example.org/m1.mp3',
            passages: ['John 1:1'],
          ),
        ],
      ),
      dailyContentProvider.overrideWith(
        (ref) => Stream.value(
          const DailyContent(
            reading: DailyEntry(title: 'John 1', reference: 'John 1'),
          ),
        ),
      ),
    ],
  );
  container
      .read(verseMarksRepositoryProvider)
      .setHighlight(
        const VerseRef('JHN', 1, 4),
        1,
        text: _words[3],
        version: 'KJV',
      );
  await container
      .read(lastReadProvider.notifier)
      .save(
        const BibleLocation('ROM', 8),
        const BibleVersion(id: 1, abbreviation: 'KJV', title: 'KJV'),
      );
  return container;
}

void main() {
  setUpAll(loadDesignAssets);

  final screens = <String, Widget Function()>{
    'bible_landing': () => const BibleScreen(),
    'bible_reader': () => const ReadingScreen(),
  };

  for (final MapEntry(key: id, value: build) in screens.entries) {
    for (final dark in const [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('$id · $mode', (tester) async {
        tester.view.physicalSize = const Size(KSize.designWidth, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = await _container();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: KharisTheme.light(),
              darkTheme: KharisTheme.dark(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: RepaintBoundary(
                key: const ValueKey('screen'),
                child: build(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/hero/sunday-bible-raised.jpg'),
            tester.element(find.byKey(const ValueKey('screen'))),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        if (Platform.isMacOS) {
          await expectLater(
            find.byKey(const ValueKey('screen')),
            matchesGoldenFile('goldens/${id}_$mode.png'),
          );
        }
      });
    }
  }

  testWidgets('the landing screen reads out its tiles', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: KharisTheme.light(),
          home: const BibleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Highlights')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Daily reading')), findsOneWidget);
    expect(find.bySemanticsLabel('Choose a passage'), findsOneWidget);
    handle.dispose();
  });
}
