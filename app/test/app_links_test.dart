import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/constants/app_links.dart';
import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/core/utils/share_sermon.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/announcement_detail.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_actions.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/features/shared_links/presentation/open_in_app_banner.dart';
import 'package:kharis_app/features/shared_links/presentation/shared_link_screens.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

const _origin = 'https://kharis-app-47c49.web.app';

/// An API message (numeric id) whose recording also has a video.
final _withVideo = Sermon(
  id: '2611',
  title: 'Grace To Continue',
  speaker: 'David Antwi',
  audioUrl: 'https://yetanothersermon.host/_/kc/media/mp3/2611.mp3',
  videoId: 'abc123',
  publishedAt: DateTime(2026, 9, 20),
  source: 'kharis-api',
);

/// An API message with only an mp3.
const _audioOnly = Sermon(
  id: '2700',
  title: 'Walking In Love',
  speaker: 'David Antwi',
  audioUrl: 'https://yetanothersermon.host/_/kc/media/mp3/2700.mp3',
  source: 'kharis-api',
);

final _prayerNight = Event(
  id: 'e-prayer',
  title: 'Prayer Night',
  description: 'An evening of corporate prayer.',
  location: 'Main Hall',
  address: '12 High Street, London',
  branch: 'London',
  startTime: DateTime(2026, 10, 16, 19),
  endTime: DateTime(2026, 10, 16, 21),
);

NewsItem _news(String id, String title, {String? branch}) => NewsItem(
  id: id,
  title: title,
  type: 'Announcement',
  publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
  body: 'Full text of $title.',
  branch: branch,
);

/// Every URL in [text] points at the Kharis host; nothing points elsewhere.
void _expectOnlyKharisLinks(String text) {
  final urls = RegExp(r'https?://\S+').allMatches(text).map((m) => m[0]!);
  expect(urls, isNotEmpty);
  for (final url in urls) {
    expect(url, startsWith('$_origin/'), reason: 'shared link $url');
  }
  for (final banned in [
    'youtube.com',
    'youtu.be',
    'yetanothersermon.host',
    'kharis.org',
  ]) {
    expect(text.contains(banned), isFalse, reason: 'no $banned in "$text"');
  }
  expect(text.contains('\u2014'), isFalse, reason: 'no em dash');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Link format ─────────────────────────────────────────────────────────────

  group('AppLinks', () {
    test('one host; message, event and announcement paths', () {
      expect(AppLinks.host, 'kharis-app-47c49.web.app');
      expect(AppLinks.message('yt_abc').toString(), '$_origin/m/yt_abc');
      expect(
        AppLinks.message(
          'yt_abc',
          at: const Duration(seconds: 95, milliseconds: 600),
          video: true,
        ).toString(),
        '$_origin/m/yt_abc?t=95&v=1',
      );
      expect(
        AppLinks.message('2700', at: Duration.zero).toString(),
        '$_origin/m/2700',
        reason: 'the very start carries no t',
      );
      expect(AppLinks.event('e1').toString(), '$_origin/e/e1');
      expect(AppLinks.announcement('n1').toString(), '$_origin/a/n1');
    });

    test('parses t and v; recognises shared paths only', () {
      expect(AppLinks.parseTime('95'), const Duration(seconds: 95));
      expect(AppLinks.parseTime('-3'), isNull);
      expect(AppLinks.parseTime('abc'), isNull);
      expect(AppLinks.parseTime(null), isNull);
      expect(AppLinks.parseVideo('1'), isTrue);
      expect(AppLinks.parseVideo('0'), isFalse);
      expect(AppLinks.isSharedPath('/m/yt_abc'), isTrue);
      expect(AppLinks.isSharedPath('/e/e1'), isTrue);
      expect(AppLinks.isSharedPath('/a/n1'), isTrue);
      expect(AppLinks.isSharedPath('/messages'), isFalse);
      expect(AppLinks.isSharedPath('/m/'), isFalse);
      expect(AppLinks.isSharedPath('/'), isFalse);
    });
  });

  // ── Share text ──────────────────────────────────────────────────────────────

  group('share text', () {
    test('audio: title, speaker and date, then the canonical Kharis link', () {
      final text = sermonShareText(_withVideo);
      expect(
        text,
        'Grace To Continue\n'
        'David Antwi, 20 September 2026\n'
        'Open in the Kharis app: $_origin/m/yt_abc123',
      );
      _expectOnlyKharisLinks(text);
    });

    test('audio and video variants of one message share one link', () {
      final cmsVariant = Sermon(
        id: 'yt_abc123',
        title: 'Grace To Continue',
        speaker: 'David Antwi',
        audioUrl: '',
        videoId: 'abc123',
        source: 'youtube',
      );
      expect(sermonShareLink(cmsVariant), sermonShareLink(_withVideo));
    });

    test('audio-only message at a position links its own id with t', () {
      final text = sermonShareText(
        _audioOnly,
        position: const Duration(seconds: 95),
      );
      expect(
        text,
        'Walking In Love\n'
        'David Antwi\n'
        'Open in the Kharis app: $_origin/m/2700?t=95',
      );
      _expectOnlyKharisLinks(text);
    });

    test('video at a time: t plus v=1, never youtu.be', () {
      final text = sermonShareText(
        _withVideo,
        asVideo: true,
        position: const Duration(minutes: 12, seconds: 30),
      );
      expect(text, endsWith('$_origin/m/yt_abc123?t=750&v=1'));
      _expectOnlyKharisLinks(text);
      expect(
        sermonShareLink(_audioOnly, asVideo: true).toString(),
        '$_origin/m/2700',
        reason: 'no v=1 for a message without a video',
      );
    });

    test('event: title, when, where, then the event link', () {
      final text = eventShareText(_prayerNight);
      expect(
        text,
        'Prayer Night\n'
        'Friday 16 October 2026, 7:00 PM \u2013 9:00 PM\n'
        'Main Hall, 12 High Street, London\n'
        'Open in the Kharis app: $_origin/e/e-prayer',
      );
      _expectOnlyKharisLinks(text);
    });
  });

  // ── Player share position ───────────────────────────────────────────────────

  group('player share', () {
    late FakeAudioPlayerService audio;
    late StreamController<Duration> videoPositions;
    final shared = <String>[];

    setUp(() {
      audio = FakeAudioPlayerService();
      videoPositions = StreamController<Duration>.broadcast();
      MediaPlayerScreen.debugDisableVideoEngine = true;
      MediaPlayerScreen.debugVideoNoteBinding = NoteTimelineBinding(
        position: videoPositions.stream,
        seek: (_) async {},
      );
      shared.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (call) async {
              shared.add((call.arguments as Map)['text'] as String);
              return 'dev.fluttercommunity.plus/share/unavailable';
            },
          );
    });

    tearDown(() async {
      MediaPlayerScreen.debugDisableVideoEngine = false;
      MediaPlayerScreen.debugVideoNoteBinding = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
      await videoPositions.close();
    });

    testWidgets(
      'sharing while watching a full-service video links the message time',
      (tester) async {
        // The message starts 10:00 into the service video.
        final service = _withVideo.copyWith(
          videoStart: const Duration(minutes: 10),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: _playerOverrides(audio, FakeCacheService()),
            child: MaterialApp(
              home: MediaPlayerScreen(sermon: service, mode: MediaMode.video),
            ),
          ),
        );
        await tester.pump();
        // 12:30 into the message = 22:30 into the video.
        videoPositions.add(const Duration(minutes: 22, seconds: 30));
        await tester.pump();

        final share = find.descendant(
          of: find.byType(PlayerActions),
          matching: find.text('Share'),
        );
        await tester.ensureVisible(share);
        await tester.tap(share);
        await tester.pump();

        expect(shared, hasLength(1));
        expect(shared.single, endsWith('$_origin/m/yt_abc123?t=750&v=1'));
        _expectOnlyKharisLinks(shared.single);
      },
    );
  });

  // ── Routing ─────────────────────────────────────────────────────────────────

  group('routing', () {
    late FakeAudioPlayerService audio;
    late FakeCacheService cache;

    setUp(() {
      audio = FakeAudioPlayerService();
      cache = FakeCacheService();
      MediaPlayerScreen.debugDisableVideoEngine = true;
      MediaPlayerScreen.debugLastVideoStart = null;
    });
    tearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);

    Future<GoRouter> pump(
      WidgetTester tester,
      String location, {
      List<Sermon> sermons = const [],
      List<Event> events = const [],
      Map<String?, List<NewsItem>> news = const {},
    }) async {
      final byId = {for (final s in sermons) s.id: s};
      byId['yt_abc123'] = _withVideo;
      final eventsById = {for (final e in events) e.id: e};
      final router = GoRouter(
        initialLocation: location,
        routes: [
          ...sharedLinkRoutes,
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home tab')),
          ),
          GoRoute(
            path: kSharedMessageHome,
            builder: (_, _) => const Scaffold(body: Text('messages tab')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._playerOverrides(audio, cache, library: sermons),
            sermonByIdProvider.overrideWith(
              (ref, id) => AsyncData<Sermon?>(byId[id]),
            ),
            eventByIdProvider.overrideWith((ref, id) async => eventsById[id]),
            myRsvpsProvider.overrideWith((ref) => Stream.value(const <Rsvp>[])),
            currentBranchProvider.overrideWith((ref) => Stream.value('London')),
            newsProvider.overrideWith(
              (ref, branch) async => news[branch] ?? const [],
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return router;
    }

    String path(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.path;

    testWidgets('/m/:id?t=&v=1 opens the video at t over Messages', (
      tester,
    ) async {
      final router = await pump(tester, '/m/yt_abc123?t=95&v=1');

      final player = tester.widget<MediaPlayerScreen>(
        find.byType(MediaPlayerScreen),
      );
      expect(player.sermon.id, '2611');
      expect(player.mode, MediaMode.video);
      expect(player.startAt, const Duration(seconds: 95));
      expect(
        MediaPlayerScreen.debugLastVideoStart,
        const Duration(seconds: 95),
      );
      expect(audio.calls, isEmpty, reason: 'video never reaches the audio');
      expect(path(router), kSharedMessageHome);

      // Closing the player lands in the app, not on an empty stack.
      router.routerDelegate.navigatorKey.currentState!.pop();
      await settle(tester);
      expect(find.byType(MediaPlayerScreen), findsNothing);
      expect(find.text('messages tab'), findsOneWidget);
    });

    testWidgets('/m/:id?t= plays the audio from t', (tester) async {
      await pump(tester, '/m/2700?t=95', sermons: const [_audioOnly]);

      final player = tester.widget<MediaPlayerScreen>(
        find.byType(MediaPlayerScreen),
      );
      expect(player.sermon.id, '2700');
      expect(player.mode, isNull, reason: 'audio-first');
      expect(audio.calls.single.sermon.id, '2700');
      expect(audio.calls.single.startAt, const Duration(seconds: 95));
    });

    testWidgets('/m/:id with v=1 for an audio-only message plays audio', (
      tester,
    ) async {
      await pump(tester, '/m/2700?v=1', sermons: const [_audioOnly]);
      expect(audio.calls.single.sermon.id, '2700');
      expect(audio.calls.single.startAt, isNull, reason: 'normal resume');
    });

    testWidgets('a video-only match waits for the audio recording while the '
        'archive fills', (tester) async {
      final videoOnly = Sermon(
        id: 'yt_abc123',
        title: 'Grace To Continue',
        speaker: 'David Antwi',
        audioUrl: '',
        videoId: 'abc123',
        source: 'youtube',
      );
      final lookup = StateProvider<Sermon>((ref) => videoOnly);
      final filling = StateProvider<bool>((ref) => true);
      final router = GoRouter(
        initialLocation: '/m/yt_abc123?t=95',
        routes: [
          ...sharedLinkRoutes,
          GoRoute(
            path: kSharedMessageHome,
            builder: (_, _) => const Text('messages tab'),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          ..._playerOverrides(audio, cache),
          sermonByIdProvider.overrideWith(
            (ref, id) => AsyncData<Sermon?>(ref.watch(lookup)),
          ),
          sharedLinkArchiveFillingProvider.overrideWith(
            (ref) => ref.watch(filling),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
      expect(find.byType(MediaPlayerScreen), findsNothing);
      expect(find.text('Opening message'), findsOneWidget);

      // The archive reaches the API record: it opens as audio, at t.
      container.read(lookup.notifier).state = _withVideo;
      container.read(filling.notifier).state = false;
      await settle(tester);
      final player = tester.widget<MediaPlayerScreen>(
        find.byType(MediaPlayerScreen),
      );
      expect(player.sermon.id, '2611');
      expect(audio.calls.single.sermon.id, '2611');
      expect(audio.calls.single.startAt, const Duration(seconds: 95));
    });

    testWidgets('a video-only message opens once the twin wait is over', (
      tester,
    ) async {
      final videoOnly = Sermon(
        id: 'yt_only',
        title: 'Livestream',
        speaker: '',
        audioUrl: '',
        videoId: 'only',
        source: 'youtube',
      );
      final router = GoRouter(
        initialLocation: '/m/yt_only',
        routes: [
          ...sharedLinkRoutes,
          GoRoute(
            path: kSharedMessageHome,
            builder: (_, _) => const Text('messages tab'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._playerOverrides(audio, cache),
            sermonByIdProvider.overrideWith(
              (ref, id) => AsyncData<Sermon?>(videoOnly),
            ),
            sharedLinkArchiveFillingProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
      expect(find.byType(MediaPlayerScreen), findsNothing);
      await tester.pump(kSharedLinkTwinWait);
      await settle(tester);
      final player = tester.widget<MediaPlayerScreen>(
        find.byType(MediaPlayerScreen),
      );
      expect(player.sermon.id, 'yt_only');
    });

    testWidgets('unknown message: not-found screen with a way Home', (
      tester,
    ) async {
      final router = await pump(tester, '/m/nope?t=5');
      expect(find.byType(SharedLinkNotFoundScreen), findsOneWidget);
      expect(find.text('We couldn\u2019t find that message'), findsOneWidget);
      expect(find.byType(MediaPlayerScreen), findsNothing);

      await tester.tap(find.byKey(const Key('shared-link-home')));
      await settle(tester);
      expect(path(router), '/home');
      expect(find.text('home tab'), findsOneWidget);
    });

    testWidgets('a message still loading after the timeout is not a spinner '
        'forever', (tester) async {
      final router = GoRouter(
        initialLocation: '/m/slow',
        routes: [
          ...sharedLinkRoutes,
          GoRoute(path: '/home', builder: (_, _) => const Text('home tab')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sermonByIdProvider.overrideWith(
              (ref, id) => const AsyncLoading<Sermon?>(),
            ),
            sermonsProvider.overrideWith((ref) async => const <Sermon>[]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.text('Opening message'), findsOneWidget);
      await tester.pump(kSharedLinkLookupTimeout);
      expect(find.byType(SharedLinkNotFoundScreen), findsOneWidget);
      expect(find.byKey(const Key('shared-link-home')), findsOneWidget);
    });

    testWidgets('/e/:id opens the event detail', (tester) async {
      await pump(tester, '/e/e-prayer', events: [_prayerNight]);
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Prayer Night'), findsWidgets);
    });

    testWidgets('unknown event: not-found screen with a way Home', (
      tester,
    ) async {
      final router = await pump(tester, '/e/gone');
      expect(find.byType(SharedLinkNotFoundScreen), findsOneWidget);
      expect(find.text('We couldn\u2019t find that event'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shared-link-home')));
      await settle(tester);
      expect(path(router), '/home');
    });

    testWidgets('/a/:id opens the announcement over the announcements list', (
      tester,
    ) async {
      await pump(
        tester,
        '/a/n1',
        news: {
          'London': [_news('n1', 'Baptism sign-ups are open')],
        },
      );
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.byType(AnnouncementDetailSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnnouncementDetailSheet),
          matching: find.text('Full text of Baptism sign-ups are open.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('/a/:id from another campus still opens', (tester) async {
      await pump(
        tester,
        '/a/n9',
        news: {
          'London': const [],
          null: [_news('n9', 'Manchester picnic', branch: 'Manchester')],
        },
      );
      expect(find.byType(AnnouncementDetailSheet), findsOneWidget);
      expect(find.text('Full text of Manchester picnic.'), findsOneWidget);
    });

    testWidgets('unknown announcement: not-found screen with a way Home', (
      tester,
    ) async {
      final router = await pump(tester, '/a/gone');
      expect(find.byType(SharedLinkNotFoundScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('shared-link-home')));
      await settle(tester);
      expect(path(router), '/home');
    });

    test('the app router serves the shared-link routes', () {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
          isAdminProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);
      final config = container.read(appRouterProvider).configuration;

      final message = config.findMatch(Uri.parse('/m/yt_abc123?t=95&v=1'));
      expect(message.matches.last.matchedLocation, '/m/yt_abc123');
      expect(message.pathParameters['id'], 'yt_abc123');
      expect(message.uri.queryParameters, {'t': '95', 'v': '1'});
      expect(config.findMatch(Uri.parse('/e/e1')).pathParameters['id'], 'e1');
      expect(config.findMatch(Uri.parse('/a/n1')).pathParameters['id'], 'n1');
    });
  });

  // ── Web banner ──────────────────────────────────────────────────────────────

  group('open-in-app banner', () {
    Future<void> pumpBanner(
      WidgetTester tester, {
      required String landed,
      bool isWeb = true,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => OpenInAppBanner(
            landed: Uri.parse('$_origin$landed'),
            isWeb: isWeb,
            platform: platform,
            child: child!,
          ),
          home: const Scaffold(body: Text('web app')),
        ),
      );
    }

    testWidgets('a shared link on web shows both actions over the app', (
      tester,
    ) async {
      await pumpBanner(tester, landed: '/m/yt_abc123?t=95');
      expect(find.text('Open in the Kharis app'), findsOneWidget);
      expect(find.text('Get the app'), findsOneWidget);
      expect(find.text('web app'), findsOneWidget, reason: 'still usable');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('open-in-app-dismiss')));
      await tester.pump();
      expect(find.text('Open in the Kharis app'), findsNothing);
      expect(find.text('web app'), findsOneWidget);
    });

    testWidgets('iOS gets no store link (no App Store id in the repo)', (
      tester,
    ) async {
      await pumpBanner(tester, landed: '/e/e1', platform: TargetPlatform.iOS);
      expect(find.text('Open in the Kharis app'), findsOneWidget);
      expect(find.text('Get the app'), findsNothing);
    });

    testWidgets('no banner off the web or off a shared path', (tester) async {
      await pumpBanner(tester, landed: '/m/x', isWeb: false);
      expect(find.byKey(const Key('open-in-app-banner')), findsNothing);
      await pumpBanner(tester, landed: '/messages');
      expect(find.byKey(const Key('open-in-app-banner')), findsNothing);
    });

    test('open-in-app targets the same link (intent on Android)', () {
      final landed = Uri.parse('$_origin/m/yt_abc123?t=95&v=1');
      expect(
        openInAppUri(landed, TargetPlatform.iOS).toString(),
        '$_origin/m/yt_abc123?t=95&v=1',
      );
      expect(
        openInAppUri(landed, TargetPlatform.android).toString(),
        'intent://kharis-app-47c49.web.app/m/yt_abc123?t=95&v=1'
        '#Intent;scheme=https;package=com.kharis.church;'
        'S.browser_fallback_url='
        'https%3A%2F%2Fplay.google.com%2Fstore%2Fapps%2Fdetails%3Fid%3D'
        'com.kharis.church;end',
      );
    });
  });

  // ── Hosting and verification files ──────────────────────────────────────────

  group('association files', () {
    test('apple-app-site-association: team app id and the three paths', () {
      final json =
          jsonDecode(
                File(
                  'web/.well-known/apple-app-site-association',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final details = (json['applinks'] as Map)['details'] as List;
      final entry = details.single as Map;
      expect(entry['appIDs'], ['Z9TTRH45X3.com.kharis.church']);
      expect(entry['appID'], 'Z9TTRH45X3.com.kharis.church');
      expect(entry['paths'], ['/m/*', '/e/*', '/a/*']);
      expect(
        [for (final c in entry['components'] as List) (c as Map)['/']],
        ['/m/*', '/e/*', '/a/*'],
      );
      // The team id is the one the iOS target signs with.
      final pbxproj = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(pbxproj, contains('DEVELOPMENT_TEAM = Z9TTRH45X3;'));
    });

    test('assetlinks.json: package and an upload-key SHA-256', () {
      final json =
          jsonDecode(File('web/.well-known/assetlinks.json').readAsStringSync())
              as List;
      final target = (json.single as Map)['target'] as Map;
      expect((json.single as Map)['relation'], [
        'delegate_permission/common.handle_all_urls',
      ]);
      expect(target['namespace'], 'android_app');
      expect(target['package_name'], 'com.kharis.church');
      final prints = target['sha256_cert_fingerprints'] as List;
      expect(prints, isNotEmpty);
      for (final print in prints) {
        expect(print, matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')));
      }
    });

    test('firebase.json: AASA as JSON, .well-known kept out of the SPA', () {
      final json =
          jsonDecode(File('firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final hosting = json['hosting'] as Map<String, dynamic>;
      expect(hosting['rewrites'], [
        {'source': '!/.well-known/**', 'destination': '/index.html'},
      ]);
      final aasa = (hosting['headers'] as List).cast<Map>().singleWhere(
        (h) => h['source'] == '/.well-known/apple-app-site-association',
      );
      expect(aasa['headers'], [
        {'key': 'Content-Type', 'value': 'application/json'},
      ]);
    });

    test('native config: entitlement and verified intent filter', () {
      expect(
        File('ios/Runner/Runner.entitlements').readAsStringSync(),
        contains('<string>applinks:kharis-app-47c49.web.app</string>'),
      );
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:autoVerify="true"'));
      expect(
        manifest,
        contains('<data android:host="kharis-app-47c49.web.app"/>'),
      );
      for (final prefix in ['/m/', '/e/', '/a/']) {
        expect(manifest, contains('android:pathPrefix="$prefix"'));
      }
    });
  });
}

List<Override> _playerOverrides(
  FakeAudioPlayerService audio,
  FakeCacheService cache, {
  List<Sermon> library = const [],
}) => [
  audioPlayerServiceProvider.overrideWithValue(audio),
  cacheServiceProvider.overrideWithValue(cache),
  sermonsProvider.overrideWith((ref) async => library),
  playlistsProvider.overrideWith((ref) => Stream.value(const <Playlist>[])),
  favoritesProvider.overrideWith((ref) => Stream.value(null)),
  notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
];

/// Advances enough fake time for a route change and its transition (the
/// loading screens spin forever, so pumpAndSettle never returns).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
