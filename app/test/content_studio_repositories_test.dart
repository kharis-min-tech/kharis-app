import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';

import 'support/fake_cache_service.dart';
import 'support/supabase_stub.dart';

/// Content Studio (Supabase) rows → app models, with the network stubbed.

Map<String, dynamic> _branch(
  String uuid,
  String slug,
  String name, {
  String group = 'Kharis',
  int order = 0,
  bool active = true,
  String? hero,
  String? giving,
}) => {
  'id': uuid,
  'slug': slug,
  'name': name,
  'subtitle': 'United Kingdom',
  'group': group,
  'sort_order': order,
  'is_active': active,
  'hero_image_url': hero,
  'giving_link': giving,
  'contact_email': '$slug@kharis.org',
  'contact_phone': '+44 1',
  'instagram': 'https://instagram.com/$slug',
  'gradient_start': '#112233',
  'gradient_end': null,
};

Map<String, dynamic> _service(
  String id,
  String branchId, {
  String day = 'Sunday',
  String start = '14:00:00',
  String? end = '16:00:00',
  String? venueId,
  int order = 0,
  bool active = true,
}) => {
  'id': id,
  'branch_id': branchId,
  'venue_id': venueId,
  'name': 'Service $id',
  'type': 'sunday',
  'day': day,
  'start_time': start,
  'end_time': end,
  'description': null,
  'sort_order': order,
  'is_active': active,
};

Map<String, dynamic> _venue(String id, String branchId) => {
  'id': id,
  'branch_id': branchId,
  'name': 'Hall $id',
  'address_line1': '1 High St',
  'address_line2': null,
  'city': 'London',
  'postcode': 'W8 7NX',
  'country': 'United Kingdom',
  'latitude': 51.5,
  'longitude': -0.19,
  'parking_info': 'Free',
  'public_transport_info': null,
  'directions_text': null,
};

final _tables = <String, List<Map<String, dynamic>>>{
  'branches': [
    _branch(
      'u-kp2',
      'kp2-barking',
      'KP2 Barking',
      group: 'Kharis Phase 2',
      order: 1,
      hero: 'http://localhost:3002/api/media/x.jpg',
    ),
    _branch(
      'u-lon',
      'london',
      'London',
      order: 2,
      hero: 'https://cdn.example.org/london.jpg',
      giving: 'https://kharis.org/giving/london',
    ),
    _branch(
      'u-acc',
      'accra',
      'Accra',
      order: 1,
      hero: 'assets/design/city-brighton.jpg',
    ),
    _branch('u-old', 'old', 'Closed', active: false),
  ],
  'services': [
    _service('pm', 'u-lon', day: 'Wednesday', start: '19:00:00', order: 2),
    _service('am', 'u-lon', venueId: 'v1', order: 1),
    _service('off', 'u-lon', active: false),
    _service('acc', 'u-acc', start: '09:00:00', end: null),
  ],
  'venues': [_venue('v1', 'u-lon'), _venue('v2', 'u-lon')],
};

// Local wall-clock instants as the Studio stores them (UTC ISO).
String _at(int y, int m, int d, int h) =>
    DateTime(y, m, d, h).toUtc().toIso8601String();

/// Tuesday 13 Oct 2026, noon.
final _now = DateTime(2026, 10, 13, 12);

Map<String, dynamic> _event(
  String id, {
  String? branch,
  String start = '',
  String? end,
  String recurrence = 'none',
  List<int> days = const [],
  String? until,
  String? image,
  List<String> sites = const ['app'],
}) => {
  'id': id,
  'title': 'Event $id',
  'sites': sites,
  'description': null,
  'location': 'Hall',
  'image_url': image,
  'branch_name': branch,
  'start_time': start,
  'end_time': end,
  'is_featured': false,
  'recurrence': recurrence,
  'recurrence_days': days,
  'recurrence_until': until,
};

void main() {
  group('usableMediaUrl', () {
    test('keeps https URLs on real hosts only', () {
      expect(usableMediaUrl(' https://x.org/a.jpg '), 'https://x.org/a.jpg');
      for (final bad in [
        null,
        '',
        '  ',
        'assets/design/city-brighton.jpg',
        'http://cdn.example.org/a.jpg',
        'http://localhost:3002/api/media/a.jpg',
        'https://localhost/a.jpg',
        'https://127.0.0.1/a.jpg',
        '/branches/hero.jpg',
        'not a url',
      ]) {
        expect(usableMediaUrl(bad), isNull, reason: '$bad');
      }
    });
  });

  group('BranchRepository', () {
    test('joins services and venues; active only; group then order', () {
      final branches = BranchRepository.joinBranches(
        _tables['branches']!,
        services: _tables['services']!,
        venues: _tables['venues']!,
      );

      expect(branches.map((b) => b.id), ['accra', 'london', 'kp2-barking']);
      final london = branches[1];
      expect(london.name, 'London');
      expect(london.group, Branch.mainGroup);
      expect(branches.last.group, Branch.phaseTwoGroup);
      expect(london.imageUrl, 'https://cdn.example.org/london.jpg');
      expect(branches.first.imageUrl, isNull, reason: 'app path');
      expect(branches.last.imageUrl, isNull, reason: 'localhost');
      expect(london.giving?.url, 'https://kharis.org/giving/london');
      expect(branches.first.giving, isNull);
      expect(london.contact.email, 'london@kharis.org');
      expect(london.contact.instagram, 'https://instagram.com/london');
      expect(london.gradientStart.toARGB32(), 0xFF112233);
      expect(london.home, isNull);

      expect(london.services.map((s) => s.id), ['am', 'pm']);
      final am = london.services.first;
      expect(am.day, 'Sunday');
      expect(am.startTime, '14:00');
      expect(am.endTime, '16:00');
      expect(london.venueById(am.venueId)?.name, 'Hall v1');
      expect(london.venues.map((v) => v.id), ['v1', 'v2']);
      expect(london.address, '1 High St, London, W8 7NX');
      expect(branches.first.services.single.endTime, isNull);
    });

    test('a cold offline launch shows the last saved branches', () async {
      final stub = SupabaseStub(_tables);
      final cache = FakeCacheService();
      final online = await BranchRepository(
        api: stub.api(cache: cache),
      ).watchBranches().toList();
      expect(online, hasLength(1), reason: 'nothing saved yet');

      stub.offline = true;
      final offline = await BranchRepository(
        api: stub.api(cache: cache),
      ).watchBranches().toList();

      expect(offline, hasLength(1));
      expect(offline.single.map((b) => b.name), [
        'Accra',
        'London',
        'KP2 Barking',
      ]);
      expect(offline.single[1].services, hasLength(2));
    });

    test('offline with nothing saved is an error, not an empty list', () {
      final stub = SupabaseStub(_tables)..offline = true;
      expect(
        BranchRepository(api: stub.api()).watchBranches().toList(),
        throwsA(anything),
      );
    });

    test('sends the publishable key and filters active rows', () async {
      final stub = SupabaseStub(_tables);
      await BranchRepository(api: stub.api()).watchBranches().first;
      final branches = stub.requests.firstWhere(
        (r) => r.uri.path.endsWith('/branches'),
      );
      expect(branches.uri.queryParameters['is_active'], 'eq.true');
      expect(branches.headers['apikey'], startsWith('sb_publishable_'));
      expect(branches.headers['Authorization'], startsWith('Bearer '));
    });
  });

  group('EventRepository', () {
    test('shows only rows the Studio shows on the app', () {
      final now = DateTime.parse(_at(2026, 10, 15, 9));
      final rows = [
        _event('app', start: _at(2026, 10, 20, 19)),
        _event('general', start: _at(2026, 10, 20, 19), sites: ['general']),
        _event('web', start: _at(2026, 10, 20, 19), sites: ['kharis', 'kp2']),
        _event('both', start: _at(2026, 10, 20, 19), sites: ['kp2', 'app']),
        _event('unpublished', start: _at(2026, 10, 20, 19), sites: []),
        {..._event('legacy', start: _at(2026, 10, 20, 19))}..remove('sites'),
      ];
      expect(
        EventRepository.upcoming(rows, branch: null, now: now).map((e) => e.id),
        unorderedEquals(['app', 'general', 'both']),
      );
      expect(EventRepository.resolve(rows, 'unpublished', now: now), isNull);
      final later = DateTime.parse(_at(2026, 10, 25, 9));
      expect(
        EventRepository.past(rows, branch: null, now: later).map((e) => e.id),
        unorderedEquals(['app', 'general', 'both']),
      );
    });

    final weekly = _event(
      'sun',
      start: _at(2026, 10, 4, 10),
      end: _at(2026, 10, 4, 12),
      recurrence: 'weekly',
      days: [0],
      image: 'https://cdn.example.org/e.jpg',
    );

    test('a weekly event is one event at its next occurrence', () {
      final e = EventRepository.fromRow(weekly, now: _now)!;
      expect(e.id, 'sun');
      expect(e.startTime, DateTime(2026, 10, 18, 10));
      expect(e.endTime, DateTime(2026, 10, 18, 12));
      expect(e.recurrenceDays, [0]);
      expect(e.recurrenceLabel, 'Every Sunday \u00b7 10:00 AM');
      expect(e.imageUrl, 'https://cdn.example.org/e.jpg');
    });

    test('several weekdays: label lists them, next is the nearest', () {
      final e = EventRepository.fromRow({
        ...weekly,
        'recurrence_days': [3, 0],
      }, now: _now)!;
      expect(e.startTime, DateTime(2026, 10, 14, 10));
      expect(e.recurrenceLabel, 'Every Sunday and Wednesday \u00b7 10:00 AM');
    });

    test('recurrence_until: kept until it passes, then hidden', () {
      final last = {...weekly, 'recurrence_until': '2026-10-18'};
      expect(
        EventRepository.fromRow(last, now: _now)?.startTime,
        DateTime(2026, 10, 18, 10),
      );
      final ended = {...weekly, 'recurrence_until': '2026-10-17'};
      expect(EventRepository.fromRow(ended, now: _now), isNull);
      expect(
        EventRepository.upcoming([ended], branch: null, now: _now),
        isEmpty,
      );
    });

    test('a series that starts later begins on its first date', () {
      final later = EventRepository.fromRow({
        ...weekly,
        'start_time': _at(2026, 11, 29, 10),
        'end_time': null,
      }, now: _now);
      expect(later?.startTime, DateTime(2026, 11, 29, 10));
    });

    test('one-off events are unchanged', () {
      final e = EventRepository.fromRow(
        _event('one', start: _at(2026, 10, 20, 19)),
        now: _now,
      )!;
      expect(e.id, 'one');
      expect(e.startTime, DateTime(2026, 10, 20, 19));
      expect(e.isWeekly, isFalse);
      expect(e.recurrenceLabel, isNull);
    });

    test('upcoming: branch scoping, past and malformed rows dropped', () {
      final rows = [
        weekly,
        _event('lon', branch: 'London', start: _at(2026, 10, 20, 19)),
        _event('lee', branch: 'Leeds', start: _at(2026, 10, 21, 19)),
        _event('gone', start: _at(2026, 10, 1, 19)),
        _event('bad', start: 'not a date'),
        _event(
          'img',
          start: _at(2026, 10, 22, 19),
          image: 'assets/design/evt-sunday.jpg',
        ),
      ];

      final london = EventRepository.upcoming(
        rows,
        branch: 'London',
        now: _now,
      );
      expect(london.map((e) => e.id), ['sun', 'lon', 'img']);
      expect(london.any((e) => e.id == 'lee'), isFalse);
      expect(london.firstWhere((e) => e.id == 'img').imageUrl, isNull);
      expect(
        EventRepository.upcoming(
          rows,
          branch: null,
          now: _now,
        ).any((e) => e.id == 'lee'),
        isTrue,
      );
    });

    test('past lists finished one-off events only, newest first', () {
      final rows = [
        weekly,
        _event('a', start: _at(2026, 9, 1, 19)),
        _event('b', start: _at(2026, 10, 1, 19), branch: 'Leeds'),
      ];
      expect(
        EventRepository.past(rows, branch: null, now: _now).map((e) => e.id),
        ['b', 'a'],
      );
      expect(
        EventRepository.past(
          rows,
          branch: 'London',
          now: _now,
        ).map((e) => e.id),
        ['a'],
      );
    });

    test('ids are plain Studio ids', () {
      final rows = [weekly, _event('one', start: _at(2026, 10, 20, 19))];

      final sun = EventRepository.resolve(rows, 'sun', now: _now);
      expect(sun?.id, 'sun');
      expect(sun?.startTime, DateTime(2026, 10, 18, 10));
      expect(EventRepository.resolve(rows, 'sun~20261018', now: _now), isNull);
      expect(EventRepository.resolve(rows, 'one', now: _now)?.id, 'one');
      expect(EventRepository.resolve(rows, 'missing', now: _now), isNull);
    });

    test('streams and lookups go through the Studio table', () async {
      final stub = SupabaseStub({
        'events': [weekly, _event('one', start: _at(2026, 10, 20, 19))],
      });
      final repo = EventRepository(api: stub.api(), clock: () => _now);

      final upcoming = await repo.watchUpcomingEvents().first;
      expect(upcoming.map((e) => e.id), ['sun', 'one']);
      expect(
        (await repo.getEventsByIds(['one', 'sun', 'nope'])).map((e) => e.id),
        unorderedEquals(['one', 'sun']),
      );
      expect((await repo.getEventById('one'))?.title, 'Event one');
    });
  });

  group('LiveRepository', () {
    test('app_config live_stream maps enabled and is_live', () {
      final on = LiveRepository.fromRows([
        {
          'key': 'live_stream',
          'value': {
            'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            'title': 'Sunday',
            'enabled': true,
          },
        },
      ]);
      expect(on.isLive, isTrue);
      expect(on.videoId, 'dQw4w9WgXcQ');
      expect(on.title, 'Sunday');

      expect(
        LiveStatus.fromConfig({'url': '', 'is_live': true}).isLive,
        isTrue,
      );
      expect(
        LiveStatus.fromConfig({'url': 'x', 'enabled': false}).isLive,
        isFalse,
      );
      expect(LiveRepository.fromRows(const []).isLive, isFalse);
    });

    test('offline is not live', () async {
      final stub = SupabaseStub({})..offline = true;
      final status = await LiveRepository(
        api: stub.api(),
      ).watchLiveStatus().first;
      expect(status.isLive, isFalse);
    });
  });
}
