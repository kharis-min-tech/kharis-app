import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

Future<void> _open(Journey j, String location) async {
  await j.resetTo('/home');
  j.c.read(appRouterProvider).go(location);
  await pumpFor(j.tester, const Duration(seconds: 1));
}

Future<void> _expectNotFound(Journey j, String location, String title) async {
  final t = j.tester;
  await _open(j, location);
  j.check(
    await pumpUntil(
      t,
      () => find.text(title).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
    ),
    '$location shows "$title"',
  );
  await j.shot('not-found-${location.split('/')[1]}');
  final home = find.byKey(const Key('shared-link-home'));
  if (home.evaluate().isNotEmpty) {
    await t.tap(home, warnIfMissed: false);
    j.check(
      await pumpUntil(t, () => find.byType(HomeScreen).evaluate().isNotEmpty),
      '"Go to Home" leaves the not-found screen for Home',
    );
  } else {
    j.check(false, '$location not-found screen offers "Go to Home"');
  }
}

/// (j) Shared links through the router: a live message, a live event, an
/// announcement when the Studio has one, and unknown ids land on the
/// friendly not-found screens.
Future<void> deepLinksJourney(Journey j) async {
  final t = j.tester;
  final r = seeded(effectiveSeed, 'deep-links');
  await j.launch();
  await openMessagesReset(j);
  j.check(await waitArchiveHydrated(j), 'archive loaded');

  // /m/<id>
  final r2 = await r2Messages();
  final library = {
    for (final s in j.c.read(sermonLibraryProvider).sermons) s.id: s,
  };
  final ids = r2.map((m) => '${m['id']}').where(library.containsKey).toList();
  j.check(ids.isNotEmpty, 'live message ids are in the library');
  if (ids.isNotEmpty) {
    final s = library[pick(r, ids)]!;
    j.note('/m/${s.id} = "${s.title}"');
    await _open(j, '/m/${Uri.encodeComponent(s.id)}');
    j.check(
      await pumpUntil(
        t,
        () => inPlayer(find.text(s.title)).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 40),
      ),
      '/m/<id> opens the player on "${s.title}"',
    );
    await j.shot('message-link');
    if (player.evaluate().isNotEmpty) await closePlayer(t);
  }

  // /e/<uuid>
  final events = await studioEvents();
  if (events.isEmpty) {
    j.note('DATA: the Studio has no events; /e/<live id> not exercised');
  } else {
    final e = pick(r, events);
    j.note('/e/${e.id} = "${e.title}"');
    await _open(j, '/e/${e.id}');
    j.check(
      await pumpUntil(
        t,
        () => find
            .descendant(
              of: find.byType(EventDetailScreen),
              matching: find.text(e.title),
            )
            .evaluate()
            .isNotEmpty,
        timeout: const Duration(seconds: 40),
      ),
      '/e/<id> opens "${e.title}"',
    );
    await j.shot('event-link');
  }

  // /a/<id>
  final news = await studioNews();
  if (news.isEmpty) {
    j.note('DATA: the Studio has no announcements; /a/<live id> not exercised');
  } else {
    final n = pick(r, news);
    final title = '${n['title']}'.trim();
    await _open(j, '/a/${n['id']}');
    j.check(
      await pumpUntil(
        t,
        () => find.text(title).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 40),
      ),
      '/a/<id> opens "$title"',
    );
    await j.shot('announcement-link');
  }

  // Unknown ids.
  final bogus = 'e2e-missing-${DateTime.now().millisecondsSinceEpoch}';
  await _expectNotFound(j, '/m/$bogus', 'We couldn\u2019t find that message');
  await _expectNotFound(
    j,
    '/e/00000000-0000-4000-8000-000000000000',
    'We couldn\u2019t find that event',
  );
  await _expectNotFound(
    j,
    '/a/$bogus',
    'We couldn\u2019t find that announcement',
  );
}
