import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/verse_marks_repository.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';

import 'support/fake_cache_service.dart';

void main() {
  late FakeCacheService cache;
  late DateTime now;

  VerseMarksRepository repository() =>
      VerseMarksRepository(cache, clock: () => now);

  const john316 = VerseRef('JHN', 3, 16);
  const john317 = VerseRef('JHN', 3, 17);
  const psalm231 = VerseRef('PSA', 23, 1);
  const loved = 'For God so loved the world that he gave his one and only Son';

  setUp(() {
    cache = FakeCacheService();
    now = DateTime(2026, 11, 11, 9);
  });

  group('VerseRef', () {
    test('names the verse the way the Bible API does', () {
      expect(john316.usfm, 'JHN.3.16');
      expect(john316.chapterId, 'JHN.3');
    });

    test('reads as the full book name and a colon', () {
      expect(john316.reference, 'John 3:16');
      expect(const VerseRef('1CO', 13, 4).reference, '1 Corinthians 13:4');
    });

    test('opens the reader on that verse', () {
      final location = john316.location;
      expect((location.usfm, location.chapter), ('JHN', 3));
      expect((location.verseStart, location.verseEnd), (16, 16));
    });
  });

  group('highlights', () {
    test('a verse is highlighted in colour 1 or 2', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      repo.setHighlight(john317, 2, text: 'For God did not', version: 'NIV');

      final marks = repo.chapter('JHN', 3);
      expect(marks.highlights[16]!.colour, 1);
      expect(marks.highlights[17]!.colour, 2);
    });

    test('any other colour is refused', () {
      expect(
        () =>
            repository().setHighlight(john316, 3, text: loved, version: 'NIV'),
        throwsArgumentError,
      );
    });

    test('changing the colour replaces the highlight', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      repo.setHighlight(john316, 2, text: loved, version: 'NIV');

      expect(repo.chapter('JHN', 3).highlights[16]!.colour, 2);
      expect(repo.highlights(), hasLength(1));
    });

    test('clearing removes it', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      repo.clearHighlight(john316);

      expect(repo.chapter('JHN', 3).isEmpty, isTrue);
      expect(repo.highlights(), isEmpty);
    });

    test('clearing a verse that has none changes nothing', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      repo.clearHighlight(john317);

      expect(repo.highlights().single.ref, john316);
    });

    test('a highlight shows in every version: it is keyed by the verse', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');

      // The reader asks by book and chapter only; no version is involved.
      expect(repo.chapter('JHN', 3).highlights.keys, [16]);
    });

    test('the list is newest first, with reference, version and text', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      now = now.add(const Duration(hours: 1));
      repo.setHighlight(
        psalm231,
        2,
        text: 'The LORD is my shepherd',
        version: 'ASV',
      );

      final list = repo.highlights();
      expect(
        [for (final h in list) h.ref.reference],
        ['Psalms 23:1', 'John 3:16'],
      );
      expect(list.first.version, 'ASV');
      expect(list.first.text, 'The LORD is my shepherd');
      expect(list.first.markedAt, DateTime(2026, 11, 11, 10));
      expect(list.last.text, loved);
    });

    test('long verse text is cut at a word, with an ellipsis', () {
      final repo = repository();
      final long = List.filled(80, 'blessed').join(' ');
      repo.setHighlight(john316, 1, text: long, version: 'NIV');

      final text = repo.highlights().single.text;
      expect(text.length, lessThanOrEqualTo(201));
      expect(text, endsWith('blessed…'));
    });

    test('line breaks in the verse become single spaces', () {
      final repo = repository();
      repo.setHighlight(
        psalm231,
        1,
        text: 'The LORD is my shepherd,\n   I lack nothing.',
        version: 'NIV',
      );

      expect(
        repo.highlights().single.text,
        'The LORD is my shepherd, I lack nothing.',
      );
    });
  });

  group('verse notes', () {
    test('a note is saved with its verse text and version', () {
      final repo = repository();
      repo.saveNote(
        john316,
        '  The heart of it.  ',
        text: loved,
        version: 'NIV',
      );

      final note = repo.chapter('JHN', 3).notes[16]!;
      expect(note.body, 'The heart of it.');
      expect(note.text, loved);
      expect(note.version, 'NIV');
      expect(note.createdAt, now);
      expect(note.updatedAt, now);
    });

    test('one note per verse: saving again edits it', () {
      final repo = repository();
      repo.saveNote(john316, 'First thought', text: loved, version: 'NIV');
      now = now.add(const Duration(days: 1));
      repo.saveNote(
        john316,
        'Second thought',
        text: 'For God so loved the world, that he gave',
        version: 'ASV',
      );

      final note = repo.notes().single;
      expect(note.body, 'Second thought');
      expect(note.version, 'NIV', reason: 'the version it was written in');
      expect(note.text, loved);
      expect(note.createdAt, DateTime(2026, 11, 11, 9));
      expect(note.updatedAt, DateTime(2026, 11, 12, 9));
    });

    test('saving an empty note removes it', () {
      final repo = repository();
      repo.saveNote(john316, 'A thought', text: loved, version: 'NIV');
      repo.saveNote(john316, '   ', text: loved, version: 'NIV');

      expect(repo.notes(), isEmpty);
    });

    test('deleting removes the note and keeps the highlight', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      repo.saveNote(john316, 'A thought', text: loved, version: 'NIV');
      repo.deleteNote(john316);

      final marks = repo.chapter('JHN', 3);
      expect(marks.notes, isEmpty);
      expect(marks.highlights.keys, [16]);
    });

    test('the list is most recently edited first', () {
      final repo = repository();
      repo.saveNote(john316, 'On love', text: loved, version: 'NIV');
      now = now.add(const Duration(hours: 1));
      repo.saveNote(psalm231, 'On rest', text: 'The LORD', version: 'NIV');
      now = now.add(const Duration(hours: 1));
      repo.saveNote(john316, 'On love, again', text: loved, version: 'NIV');

      expect(
        [for (final n in repo.notes()) n.body],
        ['On love, again', 'On rest'],
      );
    });
  });

  group('storage', () {
    test('marks survive a restart', () {
      final first = repository();
      first.setHighlight(john316, 2, text: loved, version: 'NIV');
      first.saveNote(psalm231, 'On rest', text: 'The LORD', version: 'ASV');

      final second = repository();
      expect(second.highlights().single.colour, 2);
      expect(second.notes().single.body, 'On rest');
      expect(second.notes().single.version, 'ASV');
    });

    test('a chapter with no marks left is forgotten', () {
      final repo = repository();
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      repo.clearHighlight(john316);

      expect(cache.preferences['verse_marks.JHN.3'], isNull);
      expect(cache.preferences[VerseMarksRepository.chaptersKey], '[]');
    });

    test('unreadable saved data reads as no marks', () {
      cache.preferences[VerseMarksRepository.chaptersKey] = '["JHN.3"]';
      cache.preferences['verse_marks.JHN.3'] = '{not json';

      final repo = repository();
      expect(repo.chapter('JHN', 3).isEmpty, isTrue);
      expect(repo.highlights(), isEmpty);
    });
  });

  group('providers', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(cache),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('lists, counts and the chapter view follow each change', () {
      final c = container();
      const chapter = (book: 'JHN', chapter: 3);
      final sub = c.listen(chapterMarksProvider(chapter), (_, _) {});
      addTearDown(sub.close);
      expect(c.read(verseHighlightCountProvider), 0);
      expect(c.read(verseNoteCountProvider), 0);

      final repo = c.read(verseMarksRepositoryProvider);
      repo.setHighlight(john316, 1, text: loved, version: 'NIV');
      repo.saveNote(john317, 'A thought', text: 'For God', version: 'NIV');

      expect(c.read(verseHighlightCountProvider), 1);
      expect(c.read(verseNoteCountProvider), 1);
      expect(c.read(verseHighlightsProvider).single.ref, john316);
      expect(c.read(verseNotesProvider).single.ref, john317);
      expect(sub.read().highlights.keys, [16]);
      expect(sub.read().notes.keys, [17]);

      repo.clearHighlight(john316);

      expect(c.read(verseHighlightCountProvider), 0);
      expect(sub.read().highlights, isEmpty);
    });
  });
}
