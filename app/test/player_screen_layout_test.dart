// The full player and its sheets at the 390 design width, in light and dark,
// at 100% and 130% text size: nothing overflows, the player has no back
// button (a grab handle closes it), and the transport meets the touch target.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/presentation/screens/full_player_screen.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/download_button.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/features/player/presentation/widgets/playback_error_banner.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/player/presentation/widgets/transcript_sheet.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/transcript_provider.dart';
import 'package:kharis_app/theme/kharis_theme.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

Sermon _s(String id, {String? title, String? videoId, String? transcriptUrl}) =>
    Sermon(
      id: id,
      title:
          title ??
          'The Fellowship of His Sufferings and the Power of Resurrection',
      speaker: 'Pastor Emmanuel Oluwaseun Adeyemi-Williams',
      audioUrl: 'https://cdn.example/$id.mp3',
      videoId: videoId,
      series: 'Knowing Christ in a Season of Waiting',
      category: 'Purpose & Mission',
      description:
          'A long look at Philippians 3 and what it means to count everything '
          'as loss for the surpassing worth of knowing Christ Jesus. We walk '
          'through the passage verse by verse and ask what it changes on a '
          'Monday morning.',
      publishedAt: DateTime(2026, 11, 8),
      duration: const Duration(minutes: 52),
      transcriptUrl: transcriptUrl,
    );

const _transcript =
    '[00:00] Grace and peace to you this morning.\n'
    '[00:10] Turn with me to Philippians chapter three.\n'
    '[00:30] That I may know him and the power of his resurrection.\n';

Dio _dio() => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<String>(
          requestOptions: options,
          statusCode: 200,
          data: _transcript,
        ),
      ),
    ),
  );

void main() {
  setUpAll(loadDesignAssets);

  late FakeAudioPlayerService audio;

  setUp(() => audio = FakeAudioPlayerService());

  List<Override> overrides({
    List<Sermon> library = const [],
    PlaybackFailure? failure,
  }) => [
    playbackFailureProvider.overrideWith((ref) => Stream.value(failure)),
    audioPlayerServiceProvider.overrideWithValue(audio),
    cacheServiceProvider.overrideWithValue(FakeCacheService()),
    sermonsProvider.overrideWith((ref) async => library),
    playlistsProvider.overrideWith((ref) => Stream.value(const <Playlist>[])),
    favoritesProvider.overrideWith((ref) => Stream.value(null)),
    notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
    transcriptDioProvider.overrideWithValue(_dio()),
  ];

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    required bool dark,
    required double scale,
    List<Sermon> library = const [],
    PlaybackFailure? failure,
  }) async {
    tester.view.physicalSize = const Size(KSize.designWidth, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(library: library, failure: failure),
        child: MaterialApp(
          theme: KharisTheme.light(),
          darkTheme: KharisTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the whole player past the viewport so every panel is laid out.
  Future<void> scrollThrough(WidgetTester tester) async {
    final scroll = find.byKey(const Key('player-scroll'));
    for (var i = 0; i < 6; i++) {
      await tester.drag(scroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  }

  for (final dark in const [false, true]) {
    for (final scale in const [1.0, KRatio.largeTextScale]) {
      final name = '${dark ? 'dark' : 'light'}, ${(scale * 100).round()}%';

      testWidgets('audio player lays out ($name)', (tester) async {
        final sermon = _s('1', videoId: 'v1', transcriptUrl: 'https://t/1');
        final library = [sermon, _s('2'), _s('3', title: 'Short one'), _s('4')];
        await audio.play(sermon, queue: library);
        await pump(
          tester,
          MediaPlayerScreen(
            sermon: sermon,
            mode: MediaMode.audio,
            queue: library,
          ),
          dark: dark,
          scale: scale,
          library: library,
        );
        expect(tester.takeException(), isNull);

        // The 1:1 artwork, title block, toggle, seek bar and transport.
        expect(find.byType(MediaModeToggle), findsOneWidget);
        expect(find.byType(SeekBar), findsOneWidget);
        expect(find.byType(PlayerControls), findsOneWidget);
        expect(find.byType(DownloadButton), findsOneWidget);

        await scrollThrough(tester);
        expect(find.byKey(const Key('player-up-next')), findsOneWidget);
      });

      testWidgets('audio player with a playback error lays out ($name)', (
        tester,
      ) async {
        final sermon = _s('1');
        await audio.play(sermon);
        await pump(
          tester,
          MediaPlayerScreen(sermon: sermon, mode: MediaMode.audio),
          dark: dark,
          scale: scale,
          failure: const PlaybackFailure(
            sermonId: '1',
            message:
                'Couldn\u2019t play this message. Check your connection and '
                'try again in a moment.',
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(PlaybackErrorBanner), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('video player lays out ($name)', (tester) async {
        MediaPlayerScreen.debugDisableVideoEngine = true;
        addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);
        final sermon = _s('1', videoId: 'v1');
        await pump(
          tester,
          MediaPlayerScreen(sermon: sermon, mode: MediaMode.video),
          dark: dark,
          scale: scale,
          library: [sermon, _s('2')],
        );
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
      });

      testWidgets('nothing playing lays out ($name)', (tester) async {
        await pump(tester, const FullPlayerScreen(), dark: dark, scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Nothing playing yet'), findsOneWidget);
      });

      testWidgets('transcript sheet lays out ($name)', (tester) async {
        final sermon = _s('1', transcriptUrl: 'https://t/1');
        await pump(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: KButton(
                  label: 'Open',
                  onPressed: () => TranscriptSheet.show(context, sermon),
                ),
              ),
            ),
          ),
          dark: dark,
          scale: scale,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(KBottomSheet), findsOneWidget);
        expect(find.text('Transcript'), findsOneWidget);
        expect(find.textContaining('Philippians'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'power');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('1 of 1'), findsOneWidget);
      });
    }
  }

  group('closing', () {
    final sermon = _s('1');

    Future<void> open(WidgetTester tester) async {
      await audio.play(sermon);
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: KButton(
                label: 'Open',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MediaPlayerScreen(
                      sermon: sermon,
                      mode: MediaMode.audio,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        dark: false,
        scale: 1,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(MediaPlayerScreen), findsOneWidget);
    }

    testWidgets('there is no back button; the grab handle is a "Close '
        'player" button at least 44 tall', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);

      expect(find.byType(BackButton), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is KIcon &&
              (w.asset == KIcons.chevronLeft || w.asset == KIcons.chevronDown),
        ),
        findsNothing,
      );
      final handle = find.byKey(const Key('player-grab-handle'));
      expect(
        tester.getSize(handle).height,
        greaterThanOrEqualTo(KSize.touchMin),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Close player')),
        matchesSemantics(
          label: 'Close player',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('the "Close player" semantics action closes it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await open(tester);

      tester.semantics.tap(find.semantics.byLabel('Close player'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaPlayerScreen), findsNothing);
      semantics.dispose();
    });

    testWidgets('a swipe down on the handle closes it', (tester) async {
      await open(tester);

      await tester.fling(
        find.byKey(const Key('player-grab-handle')),
        const Offset(0, 200),
        800,
      );
      await tester.pumpAndSettle();

      expect(find.byType(MediaPlayerScreen), findsNothing);
    });

    testWidgets('a swipe down from the top of the page closes it', (
      tester,
    ) async {
      await open(tester);

      await tester.fling(
        find.byKey(const Key('player-scroll')),
        const Offset(0, 300),
        1200,
      );
      await tester.pumpAndSettle();

      expect(find.byType(MediaPlayerScreen), findsNothing);
    });

    testWidgets('system back closes it', (tester) async {
      await open(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(MediaPlayerScreen), findsNothing);
    });
  });

  testWidgets('transport: five controls, each at least 44, play/pause 56, '
      'all labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    final library = [_s('1'), _s('2'), _s('3')];
    await audio.play(library[1], queue: library);
    await pump(
      tester,
      MediaPlayerScreen(
        sermon: library[1],
        mode: MediaMode.audio,
        queue: library,
      ),
      dark: false,
      scale: 1,
      library: library,
    );

    for (final key in const [
      Key('player-previous'),
      Key('skip-back'),
      Key('skip-forward'),
      Key('player-next'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(KSize.touchMin), reason: '$key');
      expect(size.height, greaterThanOrEqualTo(KSize.touchMin), reason: '$key');
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('player-play-pause'))),
      const Size(KSize.cta, KSize.cta),
    );
    for (final label in const [
      'Previous message',
      'Back 15 seconds',
      'Forward 30 seconds',
      'Next message',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    // In reading order: previous, back 15, play/pause, forward 30, next.
    final xs = [
      for (final key in const <Key>[
        Key('player-previous'),
        Key('skip-back'),
        ValueKey('player-play-pause'),
        Key('skip-forward'),
        Key('player-next'),
      ])
        tester.getCenter(find.byKey(key)).dx,
    ];
    expect(xs, [...xs]..sort());
    semantics.dispose();
  });

  testWidgets('the artwork is square with the card radius, on the page '
      'colour', (tester) async {
    final sermon = _s('1');
    await audio.play(sermon);
    await pump(
      tester,
      MediaPlayerScreen(sermon: sermon, mode: MediaMode.audio),
      dark: false,
      scale: 1,
    );

    final art = find.descendant(
      of: find.byKey(const Key('player-main')),
      matching: find.byType(ClipRRect),
    );
    final size = tester.getSize(art.first);
    expect(size.width, size.height);
    expect(size.width, KSize.designWidth - KSpace.gutter * 2);
    expect(
      tester.widget<ClipRRect>(art.first).borderRadius,
      BorderRadius.circular(KRadius.card),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      KharisColors.light.bg,
    );
  });

  testWidgets('a video-only message has no Download action', (tester) async {
    MediaPlayerScreen.debugDisableVideoEngine = true;
    addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);
    const videoOnly = Sermon(
      id: 'yt_v9',
      title: 'Sunday service',
      speaker: 'Pastor A',
      audioUrl: '',
      videoId: 'v9',
    );
    await pump(
      tester,
      const MediaPlayerScreen(sermon: videoOnly, mode: MediaMode.video),
      dark: false,
      scale: 1,
    );

    expect(find.byKey(const Key('player-download')), findsNothing);
  });
}
