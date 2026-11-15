// Home, as a member sees it: the hero, the stats strip, live and the daily
// message, the branch's news, this week's events with "Remind me", Continue
// listening, Moments and the Give card; what each opens; and that nothing
// overflows at 390 wide in light and dark at 100% and 130% text.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/event_reminder_service.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_hero.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_this_week.dart';
import 'package:kharis_app/features/messages/data/downloads_repository.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/streaks/data/streak_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/shared/providers/event_reminders_provider.dart';
import 'package:kharis_app/shared/providers/listening_history_provider.dart';
import 'package:kharis_app/shared/providers/moments_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/playlist_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_reminder_notifications.dart';

// A Wednesday evening.
final _now = DateTime(2026, 11, 11, 18, 30);

Sermon _sermon({
  String id = 's1',
  String title = 'The Portraits of Christ',
  Duration age = const Duration(days: 3),
  bool audio = true,
  String? videoId = 'vid1',
}) => Sermon(
  id: id,
  title: title,
  speaker: 'Pastor David Antwi',
  audioUrl: audio ? 'https://cdn.example/$id.mp3' : '',
  duration: const Duration(minutes: 58),
  publishedAt: _now.subtract(age),
  videoId: videoId,
  source: videoId == null ? null : 'youtube',
);

final _member = User(
  id: 'u1',
  email: 'esther@kharis.org',
  displayName: 'Esther Mensah',
  role: 'member',
  branch: 'London',
  createdAt: DateTime(2024),
);

Event _event(String id, String title, Duration inTime, {String? location}) =>
    Event(
      id: id,
      title: title,
      branch: 'London',
      location: location,
      startTime: _now.add(inTime),
    );

NewsItem _news(String id, String title, {String? body}) => NewsItem(
  id: id,
  title: title,
  type: 'Announcement',
  publishedAt: _now.subtract(const Duration(days: 1)),
  body: body,
);

const _reading = DailyContent(
  reading: DailyEntry(title: 'For such a time', reference: 'Esther 5:1-8'),
);

const _streaks = Streaks(
  readToday: false,
  readingStreak: 27,
  listenedToday: true,
  messagesStreak: 12,
  weekRead: [true, true, false, false, false, false, false],
  todayIndex: 2,
);

/// Records where Home sent the member.
class _Routes {
  final List<String> opened = [];

  GoRouter router() => GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      for (final path in const [
        '/notifications',
        '/more',
        '/reading',
        '/bible',
        '/messages',
        '/calendar',
        '/give',
        '/history',
        '/downloads',
      ])
        GoRoute(
          path: path,
          builder: (_, _) {
            opened.add(path);
            return Scaffold(body: Text('at $path'));
          },
        ),
      GoRoute(
        path: '/events/:id',
        builder: (_, state) {
          opened.add(state.uri.path);
          return Scaffold(body: Text('at ${state.uri.path}'));
        },
      ),
    ],
  );
}

class _Home {
  _Home(this.routes, this.audio, this.reminders);

  final _Routes routes;
  final FakeAudioPlayerService audio;
  final FakeReminderNotifications reminders;
}

Future<_Home> _pump(
  WidgetTester tester, {
  User? user,
  String? branch = 'London',
  List<Sermon> sermons = const [],
  bool sermonsLoading = false,
  DailyContent? reading = _reading,
  Streaks streaks = _streaks,
  LiveStatus live = LiveStatus.notLive,
  DailyMessage? dailyMessage,
  List<NewsItem> news = const [],
  AsyncValue<List<Event>>? events,
  List<UnfinishedPlay> unfinished = const [],
  Future<List<Moment>> Function()? moments,
  DownloadStatus download = const NotDownloaded(),
  bool unread = false,
  Future<ReminderOutcome> Function(Event event)? toggle,
  bool dark = false,
  double textScale = 1,
  Size size = const Size(390, 5000),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  MediaPlayerScreen.debugDisableVideoEngine = true;
  addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);

  final routes = _Routes();
  final audio = FakeAudioPlayerService();
  final reminders = FakeReminderNotifications();
  final byId = {for (final s in sermons) s.id: s};

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cacheServiceProvider.overrideWithValue(FakeCacheService()),
        audioPlayerServiceProvider.overrideWithValue(audio),
        reminderNotificationsProvider.overrideWithValue(reminders),
        clockProvider.overrideWithValue(() => _now),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        currentBranchProvider.overrideWith((ref) => Stream.value(branch)),
        branchesProvider.overrideWith(
          (ref) => Stream.value(const [
            Branch(
              id: 'london',
              name: 'London',
              subtitle: 'United Kingdom',
              gradientStart: Color(0xFF3B2A6B),
              gradientEnd: Color(0xFF7C3AED),
            ),
          ]),
        ),
        latestSermonsProvider.overrideWith((ref) => sermons),
        sermonsProvider.overrideWith(
          (ref) => sermonsLoading
              ? Future<List<Sermon>>.delayed(
                  const Duration(days: 1),
                  () => sermons,
                )
              : Future.value(sermons),
        ),
        sermonByIdProvider.overrideWith((ref, id) async => byId[id]),
        playlistsProvider.overrideWith((ref) => Stream.value(const [])),
        favoritesProvider.overrideWith((ref) => Stream.value(const [])),
        notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
        bibleIndexProvider.overrideWith(
          (ref, id) async => BibleIndex.bundled(),
        ),
        dailyContentProvider.overrideWith((ref) => Stream.value(reading)),
        dailyMessageProvider.overrideWith((ref) => Stream.value(dailyMessage)),
        streaksProvider.overrideWithValue(streaks),
        liveStatusProvider.overrideWith((ref) => Stream.value(live)),
        campusNewsProvider.overrideWithValue(AsyncValue.data(news)),
        campusUpcomingEventsProvider.overrideWithValue(
          events ?? const AsyncValue.data(<Event>[]),
        ),
        continueListeningListProvider.overrideWithValue(unfinished),
        momentsProvider.overrideWith(
          (ref) => moments == null ? Future.value(const <Moment>[]) : moments(),
        ),
        downloadStatusProvider.overrideWith((ref, id) => download),
        hasPendingNotificationsProvider.overrideWithValue(unread),
        if (toggle != null)
          toggleEventReminderProvider.overrideWithValue(toggle),
      ],
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: MaterialApp.router(
          theme: dark ? KharisTheme.dark() : KharisTheme.light(),
          routerConfig: routes.router(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await _frames(tester);
  return _Home(routes, audio, reminders);
}

/// Home can hold pulsing skeletons, so it never reliably settles.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _frames(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('hero', () {
    testWidgets('greets a member by first name, with their branch, the bell '
        'and their initial', (tester) async {
      final home = await _pump(tester, user: _member, sermons: [_sermon()]);

      expect(find.text('Good evening, Esther'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-branch-change')),
          matching: find.text('London'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-bell-unread-dot')), findsNothing);

      await _tap(tester, find.byKey(const Key('home-avatar')));
      expect(home.routes.opened, ['/more']);
    });

    testWidgets('a guest is greeted without a name and has no avatar', (
      tester,
    ) async {
      await _pump(tester, sermons: [_sermon()]);

      expect(find.text('Good evening'), findsOneWidget);
      expect(find.byKey(const Key('home-avatar')), findsNothing);
    });

    test('the greeting follows the time of day', () {
      // Covered through the widget at 18:30 above; the two other bands:
      expect(const Duration(hours: 11).inHours < 12, isTrue);
    }, skip: 'see the morning and afternoon widget tests below');

    for (final (hour, greeting) in const [
      (8, 'Good morning'),
      (14, 'Good afternoon'),
    ]) {
      testWidgets('at $hour:00 the greeting is "$greeting"', (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(
                () => DateTime(2026, 11, 11, hour),
              ),
              currentUserProvider.overrideWith((ref) => Stream.value(null)),
              currentBranchProvider.overrideWith(
                (ref) => Stream.value('London'),
              ),
              latestSermonsProvider.overrideWith((ref) => const <Sermon>[]),
              sermonsProvider.overrideWith((ref) async => const <Sermon>[]),
              hasPendingNotificationsProvider.overrideWithValue(false),
            ],
            child: MaterialApp(
              theme: KharisTheme.light(),
              home: const Scaffold(body: HomeHero()),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(greeting), findsOneWidget);
      });
    }

    testWidgets('the bell shows the unread dot and opens notifications', (
      tester,
    ) async {
      final home = await _pump(tester, unread: true);

      expect(find.byKey(const Key('home-bell-unread-dot')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Notifications, new items'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('home-bell')));
      expect(home.routes.opened, ['/notifications']);
    });

    testWidgets('the branch switcher opens the branch picker', (tester) async {
      await _pump(tester);

      await _tap(tester, find.byKey(const Key('home-branch-change')));
      expect(find.byKey(const ValueKey('branch-choice-London')), findsOneWidget);
    });

    testWidgets('a message from the last 7 days is "New from Sunday", with '
        'its title, speaker and length', (tester) async {
      await _pump(tester, sermons: [_sermon()]);

      expect(find.text('NEW FROM SUNDAY'), findsOneWidget);
      expect(find.text('The Portraits of Christ'), findsOneWidget);
      expect(find.text('Pastor David Antwi'), findsOneWidget);
      expect(find.text('58 min'), findsOneWidget);
    });

    testWidgets('an older newest message is "Latest message"', (tester) async {
      await _pump(tester, sermons: [_sermon(age: const Duration(days: 8))]);

      expect(find.text('LATEST MESSAGE'), findsOneWidget);
      expect(find.text('NEW FROM SUNDAY'), findsNothing);
    });

    testWidgets('Listen plays the message', (tester) async {
      final sermon = _sermon();
      final home = await _pump(tester, sermons: [sermon]);

      await _tap(tester, find.byKey(const Key('home-hero-listen')));
      expect(home.audio.playCalls.map((s) => s.id), ['s1']);
    });

    testWidgets('Watch is offered only when the message has video, and '
        'opens the video player', (tester) async {
      await _pump(tester, sermons: [_sermon(videoId: null)]);
      expect(find.byKey(const Key('home-hero-watch')), findsNothing);
      expect(find.byKey(const Key('home-hero-listen')), findsOneWidget);

      await _pump(tester, sermons: [_sermon()]);
      await _tap(tester, find.byKey(const Key('home-hero-watch')));
      expect(find.byType(MediaPlayerScreen), findsOneWidget);
    });

    testWidgets('the download button says where the download is', (
      tester,
    ) async {
      await _pump(tester, sermons: [_sermon()]);
      expect(
        find.bySemanticsLabel('Download The Portraits of Christ'),
        findsOneWidget,
      );

      await _pump(
        tester,
        sermons: [_sermon()],
        download: const Downloading(received: 40, total: 100),
      );
      expect(find.bySemanticsLabel('Cancel download'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.descendant(
                of: find.byKey(const Key('home-hero-download')),
                matching: find.byType(CircularProgressIndicator),
              ),
            )
            .value,
        0.4,
      );

      final home = await _pump(
        tester,
        sermons: [_sermon()],
        download: Downloaded(
          DownloadedMessage(sermon: _sermon(), bytes: 100, savedAt: _now),
        ),
      );
      expect(
        find.bySemanticsLabel('Downloaded. Open downloads'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('home-hero-download')));
      expect(home.routes.opened, ['/downloads']);
    });

    testWidgets('loading shows placeholder blocks; an empty library shows '
        'only the greeting', (tester) async {
      await _pump(tester, sermonsLoading: true);
      expect(find.byKey(const Key('home-hero-loading')), findsOneWidget);
      expect(find.byKey(const Key('home-hero-listen')), findsNothing);

      await _pump(tester);
      expect(find.byKey(const Key('home-hero-loading')), findsNothing);
      expect(find.byKey(const Key('home-hero-listen')), findsNothing);
      expect(find.text('Good evening'), findsOneWidget);
    });
  });

  group('stats strip', () {
    testWidgets("today's reading names the chapter, says Not read and opens "
        'the reading', (tester) async {
      final home = await _pump(tester);

      final cell = find.byKey(const Key('home-stat-reading'));
      expect(
        find.descendant(of: cell, matching: find.text('Esther 5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('Not read')),
        findsOneWidget,
      );
      await _tap(tester, cell);
      expect(home.routes.opened, ['/reading']);
    });

    testWidgets('a reading already read says Read', (tester) async {
      await _pump(
        tester,
        streaks: const Streaks(
          readToday: true,
          readingStreak: 28,
          listenedToday: false,
          messagesStreak: 0,
          weekRead: [true, true, true, false, false, false, false],
          todayIndex: 2,
        ),
      );

      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Not read'), findsNothing);
    });

    testWidgets('with no reading today the cell is Bible and opens it', (
      tester,
    ) async {
      final home = await _pump(tester, reading: null);

      expect(find.byKey(const Key('home-stat-reading')), findsNothing);
      expect(find.text('Bible'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('home-stat-bible')));
      expect(home.routes.opened, ['/bible']);
    });

    testWidgets('shows the reading and messages day streaks', (tester) async {
      await _pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home-stat-reading-streak')),
          matching: find.text('27'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('home-stat-messages-streak')),
          matching: find.text('12'),
        ),
        findsOneWidget,
      );
      expect(find.text('day streak'), findsNWidgets(2));
    });
  });

  group('live and daily message', () {
    testWidgets('hidden while there is no stream and no daily message', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(const Key('home-live-now')), findsNothing);
      expect(find.byKey(const Key('home-daily-message')), findsNothing);
    });

    testWidgets('a live stream shows the Live card; Watch opens the player', (
      tester,
    ) async {
      await _pump(
        tester,
        live: const LiveStatus(
          isLive: true,
          videoId: 'live123',
          title: 'Sunday Service',
        ),
      );

      final card = find.byKey(const Key('home-live-now'));
      expect(
        find.descendant(of: card, matching: find.text('Sunday Service')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(KBadge)),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('home-live-watch')));
      expect(find.byType(MediaPlayerScreen), findsOneWidget);
    });

    testWidgets('the daily message shows its message and note, and plays', (
      tester,
    ) async {
      final daily = _sermon(id: 'd1', title: 'Faith that works');
      final home = await _pump(
        tester,
        sermons: [_sermon(), daily],
        dailyMessage: const DailyMessage(
          sermonId: 'd1',
          note: 'Start your day here.',
        ),
      );

      final card = find.byKey(const Key('home-daily-message'));
      expect(
        find.descendant(of: card, matching: find.text('Faith that works')),
        findsOneWidget,
      );
      expect(find.text('Start your day here.'), findsOneWidget);
      await _tap(tester, card);
      expect(home.audio.playCalls.map((s) => s.id), ['d1']);
    });
  });

  group('branch news', () {
    testWidgets('the section is headed by the branch; announcements show '
        'their date, title and the start of the text', (tester) async {
      await _pump(
        tester,
        news: [
          _news('n1', 'Baptism Sunday', body: 'Sign up at the welcome desk.'),
          _news('n2', 'Car park closed'),
        ],
      );

      final header = find.byKey(const Key('home-branch-header'));
      expect(
        find.descendant(of: header, matching: find.text('London')),
        findsOneWidget,
      );
      expect(
        find.text('Your branch \u00b7 news and what\u2019s on'),
        findsOneWidget,
      );
      final card = find.byKey(const Key('home-announcement-n1'));
      expect(
        find.descendant(of: card, matching: find.text('Baptism Sunday')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Sign up at the welcome desk.'),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: card, matching: find.text('10')), findsOne);
      expect(find.text('Car park closed'), findsOneWidget);
    });

    testWidgets('the next announcement peeks in from the right', (
      tester,
    ) async {
      await _pump(
        tester,
        news: [_news('n1', 'Baptism Sunday'), _news('n2', 'Car park closed')],
      );

      final second = tester.getRect(
        find.byKey(const Key('home-announcement-n2')),
      );
      expect(second.left, 390 - KSize.edgeFade);
    });

    testWidgets('tapping an announcement opens it', (tester) async {
      await _pump(
        tester,
        news: [_news('n1', 'Baptism Sunday', body: 'Sign up at the desk.')],
      );

      await _tap(tester, find.text('Baptism Sunday'));
      // The announcement's own sheet: the title is now on screen twice.
      expect(find.text('Baptism Sunday'), findsNWidgets(2));
    });

    testWidgets('with no announcements the carousel is left out', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(const Key('home-announcements')), findsNothing);
      // The branch still heads This week.
      expect(find.byKey(const Key('home-branch-header')), findsOneWidget);
    });
  });

  group('this week', () {
    final prayer = _event(
      'e-prayer',
      'Prayer Night',
      const Duration(days: 2),
      location: 'Main Hall',
    );

    testWidgets('lists events in the next 7 days, soonest first, and leaves '
        'later ones out', (tester) async {
      await _pump(
        tester,
        events: AsyncValue.data([
          _event('e-late', 'Conference', const Duration(days: 8)),
          _event('e-youth', 'Youth Night', const Duration(days: 4)),
          prayer,
        ]),
      );

      expect(find.text('Conference'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Prayer Night')).dy,
        lessThan(tester.getTopLeft(find.text('Youth Night')).dy),
      );
      expect(find.text('19:30 \u00b7 Main Hall'), findsOneWidget);
    });

    testWidgets('tapping an event opens it', (tester) async {
      final home = await _pump(tester, events: AsyncValue.data([prayer]));

      await _tap(tester, find.text('Prayer Night'));
      expect(home.routes.opened, ['/events/e-prayer']);
    });

    testWidgets('"All events" opens the Events screen', (tester) async {
      final home = await _pump(tester, events: AsyncValue.data([prayer]));

      await _tap(tester, find.byKey(const Key('home-events-see-all')));
      expect(home.routes.opened, ['/calendar']);
    });

    testWidgets('Remind me schedules the reminder and says so', (tester) async {
      final home = await _pump(tester, events: AsyncValue.data([prayer]));

      expect(find.text('Remind me'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('home-event-remind-e-prayer')));

      expect(home.reminders.scheduled, hasLength(1));
      expect(find.text('Reminder on'), findsOneWidget);
      expect(
        find.text(reminderOutcomeMessage(ReminderOutcome.on)),
        findsOneWidget,
      );
    });

    for (final outcome in ReminderOutcome.values) {
      testWidgets('tells the member when the reminder is ${outcome.name}', (
        tester,
      ) async {
        await _pump(
          tester,
          events: AsyncValue.data([prayer]),
          toggle: (_) async => outcome,
        );

        await _tap(tester, find.byKey(const Key('home-event-remind-e-prayer')));
        expect(find.text(reminderOutcomeMessage(outcome)), findsOneWidget);
      });
    }

    testWidgets('an event too soon to remind about has no toggle', (
      tester,
    ) async {
      await _pump(
        tester,
        events: AsyncValue.data([
          _event('e-soon', 'Midweek Service', const Duration(minutes: 20)),
        ]),
      );

      expect(find.text('Midweek Service'), findsOneWidget);
      expect(find.text('Remind me'), findsNothing);
    });

    testWidgets('loading, empty and failed states', (tester) async {
      await _pump(tester, events: const AsyncValue.loading());
      expect(find.byKey(const Key('home-events-loading')), findsOneWidget);

      await _pump(tester, events: const AsyncValue.data([]));
      expect(find.text('Nothing on this week'), findsOneWidget);
      expect(find.byKey(const Key('home-events-see-all')), findsOneWidget);

      await _pump(
        tester,
        events: AsyncValue.error(Exception('offline'), StackTrace.empty),
      );
      expect(
        find.text('Couldn\u2019t load this week\u2019s events.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('continue listening', () {
    testWidgets('left out when nothing is unfinished', (tester) async {
      await _pump(tester);

      expect(find.byKey(const Key('home-continue-listening')), findsNothing);
      expect(find.text('Continue listening'), findsNothing);
    });

    testWidgets('lists unfinished messages; one resumes, History opens '
        'history', (tester) async {
      final home = await _pump(
        tester,
        unfinished: [
          UnfinishedPlay(
            sermon: _sermon(id: 'u1', title: 'Walking in love'),
            position: const Duration(minutes: 12, seconds: 5),
            duration: const Duration(minutes: 40),
          ),
        ],
      );

      expect(find.text('Continue listening'), findsOneWidget);
      expect(find.text('Walking in love'), findsOneWidget);
      expect(
        find.text('Pastor David Antwi \u00b7 12:05 of 40:00'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Walking in love'));
      expect(home.audio.playCalls.map((s) => s.id), ['u1']);

      await _tap(tester, find.text('History'));
      expect(home.routes.opened, ['/history']);
    });
  });

  group('moments', () {
    const clip = Moment(
      videoId: 'short1',
      title: 'Grace is enough',
      thumbnailUrl: 'https://img.example/short1.jpg',
      duration: Duration(seconds: 52),
    );

    testWidgets('shows the shorts with their length; a tap plays one', (
      tester,
    ) async {
      await _pump(tester, moments: () async => const [clip]);

      expect(find.text('Moments'), findsOneWidget);
      expect(
        find.text('Our latest shorts. Tap to watch, swipe for more.'),
        findsOneWidget,
      );
      expect(find.text('0:52'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('home-moment-short1')));
      final player = tester.widget<MediaPlayerScreen>(
        find.byType(MediaPlayerScreen),
      );
      expect(player.sermon.videoId, 'short1');
    });

    testWidgets('left out when there are none, and when they fail to load', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byKey(const Key('home-moments')), findsNothing);

      await _pump(tester, moments: () async => throw Exception('offline'));
      expect(find.byKey(const Key('home-moments')), findsNothing);
      expect(find.text('Moments'), findsNothing);
    });

    test('clips known to run under 10 seconds are dropped', () {
      Moment m(String id, Duration? d) =>
          Moment(videoId: id, title: id, thumbnailUrl: '', duration: d);

      expect(
        momentsWorthShowing([
          m('short', const Duration(seconds: 9)),
          m('ten', const Duration(seconds: 10)),
          m('unknown', null),
          m('long', const Duration(seconds: 58)),
        ]).map((x) => x.videoId),
        ['ten', 'unknown', 'long'],
      );
    });
  });

  group('give card', () {
    testWidgets('names the branch and the verse, and Give opens giving', (
      tester,
    ) async {
      final home = await _pump(tester);

      final card = find.byKey(const Key('home-give'));
      expect(
        find.descendant(of: card, matching: find.text('To London')),
        findsOneWidget,
      );
      expect(
        find.textContaining('God loveth a cheerful giver.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 Corinthians 9:7', findRichText: true),
        findsOneWidget,
      );
      // One button; no amounts, tabs or Gift Aid line.
      expect(find.textContaining('Gift Aid'), findsNothing);
      expect(find.textContaining('\u00a3'), findsNothing);

      await _tap(tester, find.byKey(const Key('home-give-button')));
      expect(home.routes.opened, ['/give']);
    });
  });

  group('page', () {
    testWidgets('pull to refresh reloads Moments', (tester) async {
      var loads = 0;
      await _pump(
        tester,
        size: const Size(390, 844),
        moments: () async {
          loads++;
          return const <Moment>[];
        },
      );
      expect(loads, 1);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _frames(tester);
      expect(loads, 2);
    });

    testWidgets('the last block clears the floating nav', (tester) async {
      await _pump(tester);

      final list = tester.getRect(find.byType(CustomScrollView));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable).first,
        ),
      );
      final give = tester.getRect(find.byKey(const Key('home-give')));
      final contentEnd =
          scrollable.position.maxScrollExtent + list.height;
      expect(contentEnd - give.bottom, KSize.contentBottomPad);
    });

    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('nothing overflows at 390 wide · '
            '${dark ? 'dark' : 'light'} · ${(scale * 100).round()}%', (
          tester,
        ) async {
          await _pump(
            tester,
            user: _member,
            dark: dark,
            textScale: scale,
            size: const Size(390, 844),
            unread: true,
            sermons: [
              _sermon(
                title: 'The Portraits of Christ: seeing Him as He truly is',
              ),
              _sermon(id: 'd1', title: 'Faith that works'),
            ],
            reading: const DailyContent(
              reading: DailyEntry(
                title: 'Two passages',
                reference: '2 Chronicles 12; Psalm 119:1-8',
              ),
            ),
            live: const LiveStatus(
              isLive: true,
              videoId: 'live123',
              title: 'Sunday Celebration Service, live from London',
            ),
            dailyMessage: const DailyMessage(
              sermonId: 'd1',
              note: 'A short word to start your day with the Lord.',
            ),
            news: [
              _news(
                'n1',
                'Baptism Sunday is coming up at the end of the month',
                body:
                    'Sign up at the welcome desk after the service, or '
                    'speak to one of the pastors.',
              ),
              _news('n2', 'Car park closed'),
            ],
            events: AsyncValue.data([
              _event(
                'e1',
                'Prayer and Worship Night with the whole church family',
                const Duration(days: 2),
                location: 'Main Hall, Kharis Centre, London',
              ),
              _event('e2', 'Youth Night', const Duration(days: 4)),
            ]),
            unfinished: [
              UnfinishedPlay(
                sermon: _sermon(id: 'u1', title: 'Walking in love every day'),
                position: const Duration(minutes: 12),
                duration: const Duration(minutes: 40),
              ),
            ],
            moments: () async => const [
              Moment(
                videoId: 'm1',
                title: 'Grace is enough for every season of your life',
                thumbnailUrl: 'https://img.example/m1.jpg',
                duration: Duration(seconds: 52),
              ),
              Moment(
                videoId: 'm2',
                title: 'He is faithful',
                thumbnailUrl: 'https://img.example/m2.jpg',
              ),
            ],
          );
          expect(tester.takeException(), isNull);

          // Every block, scrolled through.
          final scroll = find.byType(Scrollable).first;
          for (final key in const [
            'home-live-now',
            'home-daily-message',
            'home-announcements',
            'home-event-e2',
            'home-continue-listening',
            'home-moments',
            'home-give',
          ]) {
            await tester.scrollUntilVisible(
              find.byKey(Key(key)),
              300,
              scrollable: scroll,
            );
            await tester.pump();
            expect(tester.takeException(), isNull, reason: key);
          }
        });
      }
    }
  });
}
