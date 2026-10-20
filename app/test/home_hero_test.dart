import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_hero.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_sermon_repository.dart';

/// The Home hero is kharis.org's wall: the same media in the same rows,
/// drifting right, the middle card of each row in the spot. It stands still
/// whenever it should, plays only the videos on screen, and a tap plays the
/// latest message's video.

const _width = 400.0;

/// Video cards by asset, and whether each is asked to play.
final _videoCalls = <String, bool>{};

Future<void> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  bool inView = true,
  List<Sermon> latest = const [],
}) async {
  tester.view.physicalSize = const Size(_width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _videoCalls.clear();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        latestSermonsProvider.overrideWith((ref) => latest),
        audioPlayerServiceProvider.overrideWithValue(FakeAudioPlayerService()),
        cacheServiceProvider.overrideWithValue(FakeCacheService()),
        heroWallVideoProvider.overrideWithValue((asset, poster, playing) {
          _videoCalls[asset] = (_videoCalls[asset] ?? false) || playing;
          return ColoredBox(
            key: Key('video-$asset-${playing ? 'playing' : 'still'}'),
            color: Colors.black,
          );
        }),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeHero(inView: inView, topBar: const SizedBox(height: 42)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Left edge of card [i] of [row].
double _left(WidgetTester tester, int row, int i) =>
    tester.getTopLeft(find.byKey(Key('home-hero-card-$row-$i'))).dx;

/// The width one card plus its gap takes up.
double _step(WidgetTester tester) => _left(tester, 0, 1) - _left(tester, 0, 0);

/// How far [row] has moved since [before], within one loop of its cards.
double _moved(WidgetTester tester, int row, double before) {
  final set = _step(tester) * (row == 0 ? 7 : 4);
  var moved = (_left(tester, row, 0) - before) % set;
  if (moved > set / 2) moved -= set;
  return moved;
}

/// Index of [row]'s card in the spot (scaled up), and how many are.
(int, int) _spot(WidgetTester tester, int row) {
  var index = -1;
  var count = 0;
  final cards = row == 0 ? 14 : 8;
  for (var i = 0; i < cards; i++) {
    final scale = tester
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byKey(Key('home-hero-card-$row-$i')),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;
    if (scale > 1) {
      index = i;
      count++;
    }
  }
  return (index, count);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('the rows hold kharis.org\'s media in its order: both videos and '
      'every other photo on top, the rest below', () {
    expect(kHeroWallTop.map((i) => i.video ?? i.image), [
      'assets/hero/hero-a.mp4',
      'assets/hero/sunday-service-stage.jpg',
      'assets/hero/easter-bibles-raised.jpg',
      'assets/hero/hero-b.mp4',
      'assets/hero/impartation-celebration.jpg',
      'assets/hero/easter-pastor-david.jpg',
      'assets/hero/outreach-community.jpg',
    ]);
    expect(kHeroWallBottom.map((i) => i.image), [
      'assets/hero/worship-altar.jpg',
      'assets/hero/preaching-open-bible.jpg',
      'assets/hero/outreach-street.jpg',
      'assets/hero/sunday-bible-raised.jpg',
    ]);
  });

  testWidgets('cards are 80% of the screen wide; one card per row is in '
      'the spot, the one at the middle; row one starts with its first card '
      'there, row two half a card along', (tester) async {
    await _pump(tester);
    final card = tester.getSize(find.byKey(const Key('home-hero-card-0-0')));
    expect(card.width, closeTo(_width * kHeroWallCardWidth, 0.5));

    for (final row in [0, 1]) {
      final (index, count) = _spot(tester, row);
      expect(count, 1, reason: 'row $row');
      final centre = tester
          .getCenter(find.byKey(Key('home-hero-card-$row-$index')))
          .dx;
      expect((centre - _width / 2).abs(), lessThan(_step(tester) / 2 + 1));
    }
    // The first item (either copy of it: the row loops) is in the middle.
    final (spot, _) = _spot(tester, 0);
    expect(spot % 7, 0);
    expect(
      tester.getCenter(find.byKey(Key('home-hero-card-0-$spot'))).dx,
      closeTo(_width / 2, 1),
    );
    // Row two's cards fall half a card along from row one's.
    final step = _step(tester);
    expect(
      ((_left(tester, 1, 0) - _left(tester, 0, 0)) % step + step) % step,
      closeTo(step / 2, 1),
    );
  });

  testWidgets('rows drift right: one card every 6 s on top, every 7.5 s '
      'below; the spot moves on with them', (tester) async {
    await _pump(tester);
    final top = _left(tester, 0, 0);
    final bottom = _left(tester, 1, 0);
    final step = _step(tester);
    // Frame by frame, as the ticker sees them.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_moved(tester, 0, top), closeTo(step * 3 / 6, 2));
    expect(_moved(tester, 1, bottom), closeTo(step * 3 / 7.5, 2));

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // A card along: the spot has passed to the card on the left.
    expect(_spot(tester, 0).$1, anyOf(6, 13));
  });

  testWidgets('reduced motion: the wall stands still and no video plays', (
    tester,
  ) async {
    await _pump(tester, reduceMotion: true);
    final top = _left(tester, 0, 0);
    await tester.pump(const Duration(seconds: 6));
    expect(_left(tester, 0, 0), top);
    expect(_videoCalls.values, everyElement(isFalse));
  });

  testWidgets('scrolled away: the wall stands still and no video plays', (
    tester,
  ) async {
    await _pump(tester, inView: false);
    final top = _left(tester, 0, 0);
    await tester.pump(const Duration(seconds: 6));
    expect(_left(tester, 0, 0), top);
    expect(_videoCalls.values, everyElement(isFalse));
  });

  testWidgets('only a video on screen plays', (tester) async {
    await _pump(tester);
    // The first card (video A) starts in the middle; video B is three
    // cards to its right, off screen.
    expect(
      find.byKey(const Key('video-assets/hero/hero-a.mp4-playing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-assets/hero/hero-b.mp4-playing')),
      findsNothing,
    );
  });

  testWidgets('a tap plays the newest message that has a video, as video', (
    tester,
  ) async {
    MediaPlayerScreen.debugDisableVideoEngine = true;
    addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);
    await _pump(
      tester,
      latest: [
        testSermon('audio-only', publishedAt: DateTime(2026, 10, 19)),
        testSermon(
          'with-video',
          title: 'Christ: The Eternally Blessed God',
          videoId: 'abc123',
          publishedAt: DateTime(2026, 10, 12),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('home-hero-wall')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final player = tester.widget<MediaPlayerScreen>(
      find.byType(MediaPlayerScreen),
    );
    expect(player.sermon.id, 'with-video');
    expect(player.mode, MediaMode.video);
  });

  testWidgets('no message with a video yet: the tap does nothing', (
    tester,
  ) async {
    await _pump(tester, latest: [testSermon('audio-only')]);
    await tester.tap(find.byKey(const Key('home-hero-wall')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MediaPlayerScreen), findsNothing);
  });
}
