import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KA-023: the Home bell's dot must mirror the notifications feed exactly —
/// lit only while there is at least one row the member hasn't dismissed.
void main() {
  final welcome = NewsItem(
    id: 'n1',
    title: 'Welcome to the new Kharis app',
    type: 'Announcement',
    publishedAt: DateTime(2026, 9, 1),
  );
  final prayerNight = Event(
    id: 'e1',
    title: 'Prayer night',
    startTime: DateTime(2026, 9, 12, 19),
  );

  Future<ProviderContainer> build({
    List<NewsItem> news = const [],
    List<Event> events = const [],
    Set<String> dismissed = const {},
    bool newsLoading = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'notifications_dismissed_ids': dismissed.toList(),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentBranchProvider.overrideWith((ref) => Stream.value('London')),
        newsProvider.overrideWith((ref, branch) async {
          if (newsLoading) {
            return Future<List<NewsItem>>.delayed(const Duration(days: 1));
          }
          return news;
        }),
        upcomingEventsProvider.overrideWith(
          (ref, branch) => Stream.value(events),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<bool> settle(Future<ProviderContainer> pending) async {
    final c = await pending;
    // Keep the provider alive so it re-evaluates as the branch stream and the
    // async feed families resolve (a bare `read` would freeze the first value).
    final sub = c.listen(hasPendingNotificationsProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return sub.read();
  }

  test('empty feed → no dot (the fresh-install case testers hit)', () async {
    expect(await settle(build()), isFalse);
  });

  test('an undismissed announcement lights the dot', () async {
    expect(await settle(build(news: [welcome])), isTrue);
  });

  test('an upcoming event lights the dot', () async {
    expect(await settle(build(events: [prayerNight])), isTrue);
  });

  test('dot goes out once every row is dismissed', () async {
    final c = build(
      news: [welcome],
      events: [prayerNight],
      dismissed: {announcementNotificationId('n1'), eventNotificationId('e1')},
    );
    expect(await settle(c), isFalse);
  });

  test('while the feed is still loading the dot stays off', () async {
    expect(await settle(build(news: [welcome], newsLoading: true)), isFalse);
  });

  test('ids match the feed rows exactly', () {
    expect(announcementNotificationId('abc'), 'news:abc');
    expect(eventNotificationId('xyz'), 'event:xyz');
  });
}
