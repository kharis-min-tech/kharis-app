import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/notepad.dart';
import 'package:kharis_app/features/notes/presentation/screens/notepad_screen.dart';
import 'package:kharis_app/features/notes/presentation/screens/notes_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_note_repository.dart';

/// One notepad per message: `[m:ss]` stamps in free text, older
/// one-note-per-moment notes folded in, and the notebook listing one entry
/// per message whose stamps play the message from there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const message = Sermon(
    id: '2611',
    title: 'Grace Over Guilt',
    speaker: 'Pastor A',
    audioUrl: 'https://cdn.example/grace.mp3',
    videoId: 'abc123',
  );

  Note note(
    String id, {
    String? sermonId = 'yt_abc123',
    int? positionMs,
    String? body,
    int createdDay = 1,
    int updatedDay = 1,
  }) => Note(
    id: id,
    sermonId: sermonId,
    sermonTitle: sermonId == null ? null : message.title,
    positionMs: positionMs,
    body: body ?? 'note $id',
    createdAt: DateTime(2026, 3, createdDay),
    updatedAt: DateTime(2026, 3, updatedDay),
  );

  group('timestamp tokens', () {
    test('every position round-trips through its token', () {
      for (final position in const [
        Duration.zero,
        Duration(seconds: 5),
        Duration(minutes: 12, seconds: 34),
        Duration(minutes: 59, seconds: 59),
        Duration(hours: 1),
        Duration(hours: 1, minutes: 2, seconds: 7),
        Duration(hours: 10, minutes: 30),
      ]) {
        final token = noteTimestampToken(position);
        final found = findNoteTimestamps('Before $token after');
        expect(found, [
          NoteTimestamp(7, 7 + token.length, position),
        ], reason: token);
      }
      expect(
        noteTimestampToken(const Duration(minutes: 5, seconds: 15)),
        '[5:15]',
      );
      expect(
        noteTimestampToken(const Duration(hours: 1, minutes: 2, seconds: 7)),
        '[1:02:07]',
      );
    });

    test('positions are kept to the second', () {
      expect(
        findNoteTimestamps(
          noteTimestampToken(const Duration(minutes: 3, milliseconds: 1999)),
        ).single.position,
        const Duration(minutes: 3, seconds: 1),
      );
    });

    test('bracketed text that is not a time stays plain', () {
      expect(
        findNoteTimestamps(
          'Ps [23] · [75:00] · [1:60] · [12:5] · [a:bc] · [1:60:00] · 12:30',
        ),
        isEmpty,
      );
    });

    test('noteMoments marks a legacy position and every stamp', () {
      expect(
        noteMoments(note('n', positionMs: 60000, body: 'a [2:00] b [0:30]')),
        const [
          Duration(minutes: 1),
          Duration(minutes: 2),
          Duration(seconds: 30),
        ],
      );
    });
  });

  group('insertNoteTimestamp', () {
    const at = Duration(minutes: 12, seconds: 34);

    TextEditingValue cursorAt(String text, int offset) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );

    test('goes in at the cursor, spaced from the word before it', () {
      final next = insertNoteTimestamp(cursorAt('Grace is enough', 5), at);
      expect(next.text, 'Grace [12:34] is enough');
      expect(next.selection, const TextSelection.collapsed(offset: 14));
    });

    test('at the start of a line, needs no leading space', () {
      final next = insertNoteTimestamp(cursorAt('First\n', 6), at);
      expect(next.text, 'First\n[12:34] ');
      expect(next.selection, const TextSelection.collapsed(offset: 14));
    });

    test('keeps a selection, stamping in front of it', () {
      final next = insertNoteTimestamp(
        const TextEditingValue(
          text: 'Hold this',
          selection: TextSelection(baseOffset: 5, extentOffset: 9),
        ),
        at,
      );
      expect(next.text, 'Hold [12:34] this');
    });

    test('with no cursor, starts a fresh line at the end', () {
      final next = insertNoteTimestamp(
        const TextEditingValue(text: 'Opening prayer'),
        at,
      );
      expect(next.text, 'Opening prayer\n[12:34] ');
      expect(next.selection, TextSelection.collapsed(offset: next.text.length));
    });
  });

  group('composeNotepad', () {
    test(
      'folds older notes in: free text first, then stamps in time order',
      () {
        final draft = composeNotepad([
          note('late', positionMs: 900000, createdDay: 1),
          note('pad', body: 'Opening prayer', createdDay: 2),
          note(
            'early',
            positionMs: 65000,
            body: '  Grace\nmore  ',
            createdDay: 3,
          ),
          note('stray', body: 'Tagged while paused', createdDay: 4),
        ]);

        expect(draft.pad?.id, 'pad', reason: 'the oldest free note is kept');
        expect(
          draft.body,
          'Opening prayer\n'
          'Tagged while paused\n'
          '[1:05] Grace\nmore\n'
          '[15:00] note late',
        );
        expect(draft.replaces, unorderedEquals(['stray', 'early', 'late']));
      },
    );

    test('a lone notepad opens exactly as saved', () {
      final pad = note('pad', body: '[2:00] Grace  \n');
      final draft = composeNotepad([pad]);
      expect(draft.pad, pad);
      expect(draft.body, '[2:00] Grace  \n');
      expect(draft.replaces, isEmpty);
    });

    test('older notes alone start a new notepad', () {
      final draft = composeNotepad([note('a', positionMs: 5000)]);
      expect(draft.pad, isNull);
      expect(draft.body, '[0:05] note a');
      expect(draft.replaces, ['a']);
    });

    test('a note already merged by an unfinished save is not doubled, but is '
        'still retired', () {
      final draft = composeNotepad([
        note('pad', body: 'Mine\n[1:05] note a'),
        note('a', positionMs: 65000),
      ]);
      expect(draft.body, 'Mine\n[1:05] note a');
      expect(draft.replaces, ['a']);
    });
  });

  group('groupNotebook', () {
    test('one entry per message across id variants; general notes stand '
        'alone; newest first', () {
      final entries = groupNotebook(
        [
          note('a', sermonId: '2611', positionMs: 60000, updatedDay: 2),
          note('b', positionMs: 30000, updatedDay: 5),
          note('general', sermonId: null, body: 'Shopping', updatedDay: 3),
        ],
        [message],
      );

      expect(entries.map((e) => e.messageKey), ['yt_abc123', null]);
      expect(entries.first.text, '[0:30] note b\n[1:00] note a');
      expect(entries.first.title, message.title);
      expect(entries.first.updatedAt, DateTime(2026, 3, 5));
      expect(entries.last.text, 'Shopping');
    });
  });

  group('the notebook screen', () {
    late FakeAudioPlayerService audio;

    setUp(() => audio = FakeAudioPlayerService());

    Future<GoRouter> pumpNotebook(WidgetTester tester, List<Note> notes) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const NotesScreen()),
          GoRoute(
            path: '/player',
            builder: (_, _) => const Scaffold(body: Text('player')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            notesProvider.overrideWith((ref) => Stream.value(notes)),
            notesRepositoryProvider.overrideWithValue(FakeNoteRepository()),
            sermonsProvider.overrideWith((ref) async => [message]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('lists a message once, previewing its notepad', (tester) async {
      await pumpNotebook(tester, [
        note('a', sermonId: '2611', positionMs: 65000, body: 'Grace'),
        note('b', positionMs: 900000, body: 'Mercy'),
        note('general', sermonId: null, body: 'Shopping list'),
      ]);

      expect(
        find.text('[1:05] Grace\n[15:00] Mercy', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Shopping list', findRichText: true), findsOneWidget);
      expect(find.text(message.title), findsOneWidget);

      // Opening the message opens its notepad, older notes folded in.
      await tester.tap(find.text(message.title));
      await tester.pumpAndSettle();
      expect(find.byType(NotepadScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '[1:05] Grace\n[15:00] Mercy',
      );
    });

    testWidgets('a stamp in the preview plays the message from there', (
      tester,
    ) async {
      await pumpNotebook(tester, [note('a', positionMs: 65000, body: 'Grace')]);

      final preview = find.text('[1:05] Grace', findRichText: true);
      await tester.tapAt(tester.getTopLeft(preview) + const Offset(6, 6));
      await tester.pumpAndSettle();

      expect(audio.calls.single.sermon.id, message.id);
      expect(
        audio.calls.single.startAt,
        const Duration(minutes: 1, seconds: 5),
      );
      expect(find.text('player'), findsOneWidget);
    });
  });
}
