import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/home/data/featured_video_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_hero.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/content_api_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/supabase_stub.dart';

/// The Home hero with only the network stubbed: Content Studio rows
/// (`featured_videos`, `events`, `news`) → repositories → the campus feeds →
/// [homeHeroSlidesProvider] → [HomeHero]. The YouTube surface is swapped for
/// a marker so no iframe ever loads.

const _future = '2036-03-01T18:00:00Z';
const _later = '2036-04-01T18:00:00Z';
const _past = '2026-01-01T09:00:00Z';

Map<String, dynamic> _video(String workspace, String title, {String? at}) => {
  'workspace': workspace,
  'url': 'https://youtu.be/REhGafc8hdg',
  'title': title,
  'thumbnail_url': null,
  'updated_at': at ?? _past,
};

Map<String, dynamic> _event(
  String id, {
  String start = _future,
  String? image = 'https://cdn.example.org/flyer.jpg',
  List<String> sites = const ['app'],
  bool featured = false,
  String? branch,
}) => {
  'id': id,
  'title': 'Event $id',
  'start_time': start,
  'image_url': image,
  'sites': sites,
  'is_featured': featured,
  'branch_name': branch,
};

Map<String, dynamic> _news(String id, {String? image, String? eventId}) => {
  'id': id,
  'title': 'News $id',
  'workspace': 'app',
  'created_at': _past,
  'image_url': image,
  'event_id': eventId,
};

const _latest = Sermon(
  id: 's1',
  title: 'Walking by faith',
  speaker: 'Pastor Kalvert',
  audioUrl: 'https://cdn.example.org/s1.mp3',
  artworkUrl: 'https://cdn.example.org/s1.jpg',
);

List<Override> _overrides(
  SupabaseStub stub, {
  String? branch = 'London',
  List<Sermon> latest = const [_latest],
}) => [
  contentApiProvider.overrideWithValue(stub.api()),
  currentBranchProvider.overrideWith((ref) => Stream.value(branch)),
  latestSermonsProvider.overrideWith((ref) => latest),
  heroVideoSurfaceProvider.overrideWithValue(
    (videoId, onPlaying) => SizedBox(key: Key('fake-video-$videoId')),
  ),
];

/// The slides once every feed has answered.
Future<List<HeroSlide>> _slides(
  SupabaseStub stub, {
  String? branch = 'London',
  List<Sermon> latest = const [_latest],
}) async {
  final container = ProviderContainer(
    overrides: _overrides(stub, branch: branch, latest: latest),
  );
  addTearDown(container.dispose);
  final sub = container.listen(homeHeroSlidesProvider, (_, _) {});
  addTearDown(sub.close);
  await container.read(currentBranchProvider.future);
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future.wait<Object?>([
    container.read(featuredVideoProvider.future).catchError((_) => null),
    container.read(upcomingEventsProvider(branch).future),
    container.read(newsProvider(branch).future),
  ]);
  await Future<void>.delayed(Duration.zero);
  expect(
    [
      container.read(featuredVideoProvider),
      container.read(campusUpcomingEventsProvider),
      container.read(campusNewsProvider),
    ].every((f) => f.hasValue || f.hasError),
    isTrue,
    reason: 'every feed has answered',
  );
  return container.read(homeHeroSlidesProvider);
}

/// Home's rule: the hero when there are slides, nothing otherwise.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slides = ref.watch(homeHeroSlidesProvider);
    if (slides.isEmpty) return const Text('no hero');
    return SingleChildScrollView(
      child: HomeHero(
        key: const Key('home-hero'),
        slides: slides,
        topBar: const SizedBox(height: 42),
      ),
    );
  }
}

Future<void> _pumpHero(
  WidgetTester tester,
  SupabaseStub stub, {
  bool reduceMotion = false,
  List<Sermon> latest = const [_latest],
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(stub, latest: latest),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const Scaffold(body: _Host()),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('featured video choice', () {
    test('the app\'s clip beats General, which beats Kharis; KP2 never', () {
      final all = [
        _video('kp2', 'Kharis Phase 2'),
        _video('kharis', 'Year of Faith highlight'),
        _video('general', 'General clip'),
        _video('app', 'App clip'),
      ];
      expect(FeaturedVideoRepository.pick(all)?.title, 'App clip');
      expect(
        FeaturedVideoRepository.pick(all.sublist(0, 3))?.title,
        'General clip',
      );
      expect(
        FeaturedVideoRepository.pick(all.sublist(0, 2))?.title,
        'Year of Faith highlight',
      );
      expect(FeaturedVideoRepository.pick(all.sublist(0, 1)), isNull);
    });

    test('the newest clip in a workspace wins; the thumbnail falls back to '
        'YouTube\'s frame', () {
      final video = FeaturedVideoRepository.pick([
        _video('kharis', 'Older', at: '2025-01-01T00:00:00Z'),
        _video('kharis', 'Newer', at: '2026-06-01T00:00:00Z'),
      ])!;
      expect(video.title, 'Newer');
      expect(video.videoId, 'REhGafc8hdg');
      expect(
        video.thumbnailUrl,
        'https://i.ytimg.com/vi/REhGafc8hdg/hqdefault.jpg',
      );
    });
  });

  group('slides', () {
    test(
      'video first, then flyers (featured, then soonest), then '
      'announcement images; a promo for a shown event is not repeated',
      () async {
        final slides = await _slides(
          SupabaseStub({
            'featured_videos': [
              _video('kharis', 'Kharis clip'),
              _video('general', 'General clip'),
            ],
            'events': [
              _event('soon'),
              _event('featured', start: _later, featured: true),
              _event('plain', image: null),
            ],
            'news': [
              _news('pic', image: 'https://cdn.example.org/news.jpg'),
              _news('text-only'),
              _news(
                'promo',
                image: 'https://cdn.example.org/promo.jpg',
                eventId: 'soon',
              ),
            ],
          }),
        );
        expect(slides.map((s) => s.id), [
          'video:REhGafc8hdg',
          'event:featured',
          'event:soon',
          'news:pic',
        ]);
        expect((slides.first as VideoHeroSlide).video.title, 'General clip');
      },
    );

    test('only events the app shows for the member\'s Branch', () async {
      final slides = await _slides(
        SupabaseStub({
          'featured_videos': [],
          'events': [
            _event('mine', branch: 'London'),
            _event('everyone'),
            _event('website-only', sites: ['kharis']),
            _event('unpublished', sites: []),
            _event('leeds', branch: 'Leeds'),
          ],
          'news': [],
        }),
      );
      expect(slides.map((s) => s.id), ['event:mine', 'event:everyone']);
    });

    test('nothing else → the latest message; a failed video feed does not '
        'hide it', () async {
      final slides = await _slides(
        // No `featured_videos` table: the stub fails it like a dropped line.
        SupabaseStub({
          'events': [_event('no-flyer', image: null)],
          'news': [_news('text-only')],
        }),
      );
      expect(slides, hasLength(1));
      expect((slides.single as LatestMessageHeroSlide).sermon.id, 's1');
    });

    test('nothing at all → no slides', () async {
      final slides = await _slides(
        SupabaseStub({'featured_videos': [], 'events': [], 'news': []}),
        latest: const [],
      );
      expect(slides, isEmpty);
    });
  });

  group('HomeHero', () {
    final withVideo = {
      'featured_videos': [_video('app', 'App clip')],
      'events': [_event('soon')],
      'news': <Map<String, dynamic>>[],
    };

    testWidgets('plays the clip on its slide, title and Watch below, dots '
        'for more than one slide', (tester) async {
      await _pumpHero(tester, SupabaseStub(withVideo));

      expect(find.byKey(const Key('home-hero')), findsOneWidget);
      expect(find.byKey(const Key('fake-video-REhGafc8hdg')), findsOneWidget);
      // The thumbnail stays until the surface reports frames.
      expect(
        find.byKey(const Key('home-hero-video-thumbnail')),
        findsOneWidget,
      );
      expect(find.text('App clip'), findsOneWidget);
      expect(find.text('Watch'), findsOneWidget);
      expect(find.byKey(const Key('home-hero-play')), findsOneWidget);
      expect(find.byKey(const Key('home-hero-dots')), findsOneWidget);
    });

    testWidgets('reduced motion: the still thumbnail, no player, no '
        'auto-advance', (tester) async {
      await _pumpHero(tester, SupabaseStub(withVideo), reduceMotion: true);

      expect(find.byKey(const Key('fake-video-REhGafc8hdg')), findsNothing);
      expect(
        find.byKey(const Key('home-hero-video-thumbnail')),
        findsOneWidget,
      );
      await tester.pump(kHeroAdvanceInterval * 2);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('App clip'), findsOneWidget);
    });

    testWidgets('image slides advance on their own', (tester) async {
      await _pumpHero(
        tester,
        SupabaseStub({
          'featured_videos': [],
          'events': [_event('a'), _event('b', start: _later)],
          'news': [],
        }),
      );
      expect(find.text('Event a'), findsOneWidget);

      await tester.pump(kHeroAdvanceInterval);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Event b'), findsOneWidget);
      expect(find.text('Event a'), findsNothing);
    });

    testWidgets('the latest-message fallback offers Play, without dots', (
      tester,
    ) async {
      await _pumpHero(
        tester,
        SupabaseStub({'featured_videos': [], 'events': [], 'news': []}),
      );

      expect(find.text('LATEST MESSAGE'), findsOneWidget);
      expect(find.text('Walking by faith'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.byKey(const Key('home-hero-dots')), findsNothing);
    });

    testWidgets('nothing to show → no hero', (tester) async {
      await _pumpHero(
        tester,
        SupabaseStub({'featured_videos': [], 'events': [], 'news': []}),
        latest: const [],
      );

      expect(find.byKey(const Key('home-hero')), findsNothing);
      expect(find.text('no hero'), findsOneWidget);
    });
  });
}
