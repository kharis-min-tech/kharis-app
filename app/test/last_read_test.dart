import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/last_read_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

void main() {
  final opened = DateTime(2026, 11, 11, 8, 30);
  const nasb = BibleVersion(
    id: 2692,
    abbreviation: 'NASB2020',
    title: 'New American Standard Bible',
  );

  Future<ProviderContainer> container([
    Map<String, Object> saved = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => opened),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  String stored({
    String book = 'JHN',
    int chapter = 3,
    int bibleId = 2692,
    String abbreviation = 'NASB2020',
  }) => jsonEncode({
    'book': book,
    'chapter': chapter,
    'bibleId': bibleId,
    'abbreviation': abbreviation,
    'openedAt': opened.millisecondsSinceEpoch,
  });

  test('null before any chapter has been opened', () async {
    final c = await container();

    expect(c.read(lastReadProvider), isNull);
  });

  test('opening a chapter records its book, chapter and version', () async {
    final c = await container();

    await c
        .read(lastReadProvider.notifier)
        .save(const BibleLocation('JHN', 3), nasb);

    final last = c.read(lastReadProvider)!;
    expect(last.book, 'JHN');
    expect(last.chapter, 3);
    expect(last.bibleId, 2692);
    expect(last.abbreviation, 'NASB2020');
    expect(last.openedAt, opened);
    expect(last.location.usfm, 'JHN');
    expect(last.location.chapter, 3);
  });

  test('a verse selection is left out: the place kept is a chapter', () async {
    final c = await container();

    await c
        .read(lastReadProvider.notifier)
        .save(
          const BibleLocation('ROM', 8, verseStart: 28, verseEnd: 30),
          kDefaultBibleVersion,
        );

    final location = c.read(lastReadProvider)!.location;
    expect(location.verseStart, isNull);
    expect(location.verseEnd, isNull);
  });

  test('the latest chapter replaces the one before', () async {
    final c = await container();
    final controller = c.read(lastReadProvider.notifier);

    await controller.save(const BibleLocation('JHN', 3), nasb);
    await controller.save(const BibleLocation('PSA', 23), kDefaultBibleVersion);

    final last = c.read(lastReadProvider)!;
    expect((last.book, last.chapter, last.abbreviation), ('PSA', 23, 'NIV'));
  });

  test('it is remembered after a restart', () async {
    final c = await container({LastReadController.key: stored()});

    final last = c.read(lastReadProvider)!;
    expect((last.book, last.chapter, last.bibleId), ('JHN', 3, 2692));
    expect(last.openedAt, opened);
  });

  test('what save writes is what a restart reads', () async {
    final first = await container();
    await first
        .read(lastReadProvider.notifier)
        .save(const BibleLocation('JHN', 3), nasb);
    final prefs = await SharedPreferences.getInstance();

    final second = await container({
      LastReadController.key: prefs.getString(LastReadController.key)!,
    });

    expect(second.read(lastReadProvider), first.read(lastReadProvider));
  });

  test(
    'a version the church no longer approves reopens in the default',
    () async {
      final c = await container({
        LastReadController.key: stored(bibleId: 9999, abbreviation: 'OLD'),
      });

      final last = c.read(lastReadProvider)!;
      expect((last.book, last.chapter), ('JHN', 3));
      expect(last.bibleId, kDefaultBibleVersion.id);
      expect(last.abbreviation, kDefaultBibleVersion.abbreviation);
    },
  );

  test('a chapter the book does not have is not offered', () async {
    final c = await container({LastReadController.key: stored(chapter: 40)});

    expect(c.read(lastReadProvider), isNull, reason: 'John has 21 chapters');
  });

  test('an unknown book is not offered', () async {
    final c = await container({LastReadController.key: stored(book: 'XYZ')});

    expect(c.read(lastReadProvider), isNull);
  });

  test('unreadable saved data reads as nothing opened', () async {
    final c = await container({LastReadController.key: '{not json'});

    expect(c.read(lastReadProvider), isNull);
  });
}
