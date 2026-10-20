import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/player/data/related_messages.dart';
import 'package:kharis_app/features/player/presentation/artwork_tint.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

Sermon _s(
  String id, {
  String speaker = 'David Antwi',
  String? series,
  DateTime? at,
  String? videoId,
  bool audio = true,
  Duration? duration,
  List<String> related = const [],
  String? artworkUrl,
}) => Sermon(
  id: id,
  title: 'Message $id',
  speaker: speaker,
  audioUrl: audio ? 'https://cdn.example/$id.mp3' : '',
  series: series,
  publishedAt: at,
  videoId: videoId,
  duration: duration,
  relatedIds: related,
  artworkUrl: artworkUrl,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Model ───────────────────────────────────────────────────────────────────

  group('Sermon related ids and tags', () {
    test('survive the archive round trip and copyWith', () {
      final s = _s('1', related: ['2', '3']).copyWith(tags: ['PDAK', 'Kharis']);
      final back = Sermon.fromJson(s.toJson());
      expect(back, s);
      expect(back.relatedIds, ['2', '3']);
      expect(back.tags, ['PDAK', 'Kharis']);
      expect(back.copyWith(title: 'x').relatedIds, ['2', '3']);
    });

    test('caches written before them still load; empty lists are omitted', () {
      final legacy = {'id': '1', 'title': 'T', 'speaker': 'S', 'audioUrl': ''};
      final s = Sermon.fromJson(legacy);
      expect(s.relatedIds, isEmpty);
      expect(s.tags, isEmpty);
      expect(s.toJson().keys, isNot(contains('relatedIds')));
      expect(s.toJson().keys, isNot(contains('tags')));
    });
  });

  // ── Ranking ─────────────────────────────────────────────────────────────────

  group('relatedMessages', () {
    final current = _s(
      '100',
      series: 'Faith Walk',
      at: DateTime(2024, 5, 10),
      videoId: 'v100',
      related: ['300', '200', '999', '100'],
    );
    // The CMS copy of the same message, carrying one more site pick.
    final currentVariant = _s(
      'yt_v100',
      audio: false,
      videoId: 'v100',
      related: ['400'],
    );
    final library = [
      _s('p-old', at: DateTime(2020)),
      _s('p-nodate'),
      _s('p-new', at: DateTime(2025)),
      // Another variant of 300: listed once only.
      _s('yt_v300', audio: false, videoId: 'v300', at: DateTime(2026)),
      _s('s-nodate', speaker: 'Other', series: 'faith walk '),
      _s('s-far', speaker: 'Other', series: 'Faith Walk', at: DateTime(2023)),
      _s(
        's-near',
        speaker: 'Other',
        series: 'Faith Walk',
        at: DateTime(2024, 5, 3),
      ),
      _s('short', videoId: 'vs', duration: const Duration(minutes: 1)),
      _s('silent', audio: false),
      _s('400', speaker: 'Other'),
      _s('300', speaker: 'Other', videoId: 'v300'),
      _s('200', speaker: 'Other'),
      currentVariant,
      current,
    ];

    test('site picks, then series by date distance, then speaker newest', () {
      expect(relatedMessages(current, library).map((s) => s.id), [
        '300',
        '200',
        '400',
        's-near',
        's-far',
        's-nodate',
        'p-new',
        'p-old',
        'p-nodate',
      ]);
    });
    test('opened from another variant, the same messages come back', () {
      expect(
        relatedMessages(currentVariant, library).map((s) => s.id),
        unorderedEquals(relatedMessages(current, library).map((s) => s.id)),
      );
    });

    test('caps at the limit', () {
      expect(relatedMessages(current, library, limit: 3).map((s) => s.id), [
        '300',
        '200',
        '400',
      ]);
    });

    test('nothing related: empty, never the message itself', () {
      expect(relatedMessages(current, [current, currentVariant]), isEmpty);
      expect(relatedMessages(_s('x', speaker: ' '), library), isEmpty);
    });
  });

  // ── Contrast ────────────────────────────────────────────────────────────────

  group('tintedPlayerColors', () {
    const seeds = [
      Color(0xFFFFEB3B), // bright yellow
      Color(0xFF0D47A1), // deep blue
      Color(0xFFE53935), // red
      Color(0xFF9E9E9E), // grey artwork
      Color(0xFFFFFFFF),
      Color(0xFF000000),
    ];
    for (final brightness in Brightness.values) {
      test('text stays WCAG AA on every tint ($brightness)', () {
        final base = brightness == Brightness.dark
            ? KharisColors.dark
            : KharisColors.light;
        for (final seed in seeds) {
          final kc = tintedPlayerColors(
            base,
            ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
            brightness,
          );
          expect(kc.bg.a, 1.0, reason: 'a solid surface');
          if (brightness == Brightness.light) {
            expect(kc.bg.computeLuminance(), greaterThan(0.6), reason: '$seed');
          }
          for (final surface in [kc.bg, kc.surfaceMuted]) {
            for (final (name, fg) in [
              ('onBg', kc.onBg),
              ('muted', kc.muted),
              ('accentInk', kc.accentInk),
            ]) {
              expect(
                contrastRatio(fg, surface),
                greaterThanOrEqualTo(kTextContrastAA),
                reason: '$name on $surface (seed $seed)',
              );
            }
          }
        }
      });
    }
  });

  // ── Player ──────────────────────────────────────────────────────────────────

  group('player', () {
    late FakeAudioPlayerService audio;

    setUp(() => audio = FakeAudioPlayerService());

    Future<void> open(
      WidgetTester tester,
      Sermon sermon, {
      List<Sermon> library = const [],
      List<Sermon>? queue,
      MediaMode mode = MediaMode.audio,
      ArtworkSchemeSource? colours,
      Brightness brightness = Brightness.dark,
      bool reduceMotion = false,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            cacheServiceProvider.overrideWithValue(FakeCacheService()),
            sermonsProvider.overrideWith((ref) async => library),
            playlistsProvider.overrideWith(
              (ref) => Stream.value(const <Playlist>[]),
            ),
            favoritesProvider.overrideWith((ref) => Stream.value(null)),
            notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
            artworkSchemeSourceProvider.overrideWithValue(
              colours ?? (_, _) async => null,
            ),
          ],
          child: MaterialApp(
            theme: kharisTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: MediaPlayerScreen(sermon: sermon, mode: mode, queue: queue),
          ),
        ),
      );
      await tester.pump();
    }

    Finder inUpNext(String text) => find.descendant(
      of: find.byKey(const Key('player-up-next')),
      matching: find.text(text),
    );

    group('Up next', () {
      final queue = [_s('1'), _s('2'), _s('3')];

      testWidgets('shows the queue\'s next message; a tap skips to it', (
        tester,
      ) async {
        await audio.play(queue.first, queue: queue);
        await open(tester, queue.first, queue: queue);

        expect(inUpNext('Message 2'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^Up next, Message 2')),
          findsOneWidget,
        );

        await tester.ensureVisible(find.byKey(const Key('player-up-next')));
        await tester.tap(find.byKey(const Key('player-up-next')));
        await tester.pumpAndSettle();

        expect(audio.nextCalls, 1);
        expect(audio.current?.id, '2');
        expect(inUpNext('Message 3'), findsOneWidget);
      });

      testWidgets('hidden at the end of the queue', (tester) async {
        await audio.play(queue.last, queue: queue);
        await open(tester, queue.last, queue: queue);

        expect(find.byKey(const Key('player-up-next')), findsNothing);
      });

      testWidgets('video mode walks the video queue', (tester) async {
        MediaPlayerScreen.debugDisableVideoEngine = true;
        addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);
        final videos = [
          _s('5', audio: false, videoId: 'v5'),
          _s('6', audio: false, videoId: 'v6'),
        ];
        await open(tester, videos.first, queue: videos, mode: MediaMode.video);

        expect(inUpNext('Message 6'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('player-up-next')));
        await tester.tap(find.byKey(const Key('player-up-next')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('player-up-next')), findsNothing);
        expect(audio.calls, isEmpty, reason: 'video stays in video');
      });
    });

    group('You might also like', () {
      final current = _s('1', series: 'Grace', related: ['9']);
      final library = [
        current,
        _s('2', speaker: 'Other', series: 'Grace'),
        _s('9', speaker: 'Other'),
      ];

      testWidgets('lists related messages; a tap plays it with the rail as '
          'the queue', (tester) async {
        await audio.play(current, queue: [current]);
        await open(tester, current, library: library, queue: [current]);

        final rail = find.byKey(const Key('player-related'));
        expect(rail, findsOneWidget);
        expect(find.text('You might also like'), findsOneWidget);
        final first = find.descendant(
          of: rail,
          matching: find.text('Message 9'),
        );
        final second = find.descendant(
          of: rail,
          matching: find.text('Message 2'),
        );
        expect(
          tester.getTopLeft(first).dx,
          lessThan(tester.getTopLeft(second).dx),
        );

        await tester.ensureVisible(first);
        await tester.tap(first);
        await tester.pumpAndSettle();

        expect(audio.calls.last.sermon.id, '9');
        expect(audio.calls.last.queue?.map((s) => s.id), ['9', '2']);
        // The rail is the queue now, so Up next follows it.
        expect(inUpNext('Message 2'), findsOneWidget);
      });

      testWidgets('hidden when nothing is related', (tester) async {
        await audio.play(current, queue: [current]);
        await open(tester, current, library: [current], queue: [current]);

        expect(find.byKey(const Key('player-related')), findsNothing);
        expect(find.text('You might also like'), findsNothing);
      });
    });

    group('Explore', () {
      testWidgets('a series tile closes the player and opens Messages '
          'filtered to that series alone', (tester) async {
        final current = _s('1', series: 'Grace');
        await audio.play(current, queue: [current]);
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const Text('home')),
            GoRoute(
              path: '/messages',
              builder: (_, _) => const Text('messages page'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioPlayerServiceProvider.overrideWithValue(audio),
              cacheServiceProvider.overrideWithValue(FakeCacheService()),
              sermonsProvider.overrideWith((ref) async => [current]),
              playlistsProvider.overrideWith(
                (ref) => Stream.value(const <Playlist>[]),
              ),
              favoritesProvider.overrideWith((ref) => Stream.value(null)),
              notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
              artworkSchemeSourceProvider.overrideWithValue(
                (_, _) async => null,
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.text('home')),
        );
        // An earlier filter must not stack with the tile's.
        container.read(selectedSpeakerProvider.notifier).state = 'Someone';
        unawaited(
          Navigator.of(tester.element(find.text('home'))).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  MediaPlayerScreen(sermon: current, queue: [current]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const Key('player-explore-series'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        expect(find.text('More from Grace'), findsOneWidget);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        expect(find.byType(MediaPlayerScreen), findsNothing);
        expect(find.text('messages page'), findsOneWidget);
        expect(container.read(selectedSeriesProvider), 'Grace');
        expect(container.read(selectedSpeakerProvider), isNull);
      });
    });

    group('compact bar', () {
      final current = _s('1', series: 'Grace', related: ['9']);
      final library = [
        current,
        _s('2', speaker: 'Other', series: 'Grace'),
        _s('9', speaker: 'Other'),
      ];

      bool barShown(WidgetTester tester) =>
          tester
              .widget<AnimatedOpacity>(
                find.ancestor(
                  of: find.byKey(const Key('player-compact-bar')),
                  matching: find.byType(AnimatedOpacity),
                ),
              )
              .opacity ==
          1;

      testWidgets('appears only once the transport has scrolled away, and '
          'pauses from there', (tester) async {
        await audio.play(current, queue: [current]);
        await open(tester, current, library: library, queue: [current]);
        await tester.pumpAndSettle();
        expect(barShown(tester), isFalse, reason: 'transport on screen');

        await tester.drag(
          find.byKey(const Key('player-scroll')),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(barShown(tester), isTrue, reason: 'transport scrolled away');

        // Playing: the bar offers Pause; paused: Play resumes.
        audio.playerStates.add(PlayerState(true, ProcessingState.ready));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('player-compact-play')));
        await tester.pump();
        expect(audio.pauseCalls, 1);
        audio.playerStates.add(PlayerState(false, ProcessingState.ready));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('player-compact-play')));
        await tester.pump();
        expect(audio.resumeCalls, 1);
      });
    });

    group('artwork tint', () {
      final art = _s('1', artworkUrl: 'https://cdn.example/1.jpg');
      Color headerColour(WidgetTester tester) => tester
          .widget<ColoredBox>(find.byKey(const Key('player-tint-header')))
          .color;
      Color bodyColour(WidgetTester tester) =>
          (tester
                      .widget<DecoratedBox>(
                        find.byKey(const Key('player-tint-body')),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;

      for (final brightness in Brightness.values) {
        testWidgets('the top of the player takes the artwork colour '
            '($brightness)', (tester) async {
          final scheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: brightness,
          );
          final requested = <(String, Brightness)>[];
          await audio.play(art);
          await open(
            tester,
            art,
            brightness: brightness,
            colours: (url, b) async {
              requested.add((url, b));
              return scheme;
            },
          );
          await tester.pumpAndSettle();

          final base = brightness == Brightness.dark
              ? KharisColors.dark
              : KharisColors.light;
          final tint = tintedPlayerColors(base, scheme, brightness);
          expect(requested, [('https://cdn.example/1.jpg', brightness)]);
          expect(headerColour(tester), tint.bg);
          expect(bodyColour(tester), tint.bg);
          expect(tint.bg, isNot(base.bg));
          final title = tester.widget<Text>(find.text('Message 1').first);
          expect(
            contrastRatio(title.style!.color!, tint.bg),
            greaterThanOrEqualTo(kTextContrastAA),
          );
        });
      }

      testWidgets('falls back to the page colour when extraction fails', (
        tester,
      ) async {
        for (final colours in <ArtworkSchemeSource>[
          (_, _) async => null,
          (_, _) async => throw StateError('decode failed'),
        ]) {
          await audio.play(art);
          await open(tester, art, colours: colours);
          await tester.pumpAndSettle();

          expect(headerColour(tester), KharisColors.dark.bg);
          expect(bodyColour(tester), KharisColors.dark.bg);
          // Fresh scope for the next source.
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('reduced motion: the colour changes without a fade', (
        tester,
      ) async {
        final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFFC62828),
          brightness: Brightness.dark,
        );
        final tint = tintedPlayerColors(
          KharisColors.dark,
          scheme,
          Brightness.dark,
        );

        await audio.play(art);
        await open(tester, art, colours: (_, _) async => scheme);
        await tester.pump();
        expect(headerColour(tester), isNot(tint.bg), reason: 'fading in');
        await tester.pumpAndSettle();
        expect(headerColour(tester), tint.bg);

        await tester.pumpWidget(const SizedBox());
        await open(
          tester,
          art,
          colours: (_, _) async => scheme,
          reduceMotion: true,
        );
        await tester.pump();
        expect(headerColour(tester), tint.bg, reason: 'no animation frames');
      });
    });
  });
}
