import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/daily_message_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/todays_reading_card.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_cache_service.dart';
import 'support/supabase_stub.dart';

/// Today's reading, prayer and message from the Content Studio (Supabase),
/// with the network stubbed. The stub ignores query filters, so these also
/// prove the client-side kind, workspace and date checks.
final _now = DateTime(2026, 10, 16, 9, 30);
const _today = '2026-10-16';

Map<String, dynamic> _entry({
  String kind = 'reading',
  String workspace = 'app',
  String? date = _today,
  String? title = 'God so loved',
  String? body = 'Read it slowly.',
  String? reference = 'John 3:16-18',
}) => {
  'id': '$kind-$workspace-$date-$title',
  'workspace': workspace,
  'kind': kind,
  'date': date,
  'title': title,
  'body': body,
  'reference': reference,
};

/// A Studio whose database does not have [missing] yet: PostgREST answers
/// those tables with a 404 (`PGRST205`).
class _Studio extends SupabaseStub {
  _Studio(super.tables, {this.missing = const {}});

  final Set<String> missing;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (missing.contains(options.uri.pathSegments.last)) {
      requests.add(options);
      return Future.value(
        ResponseBody.fromString(
          '{"code":"PGRST205","message":"Could not find the table"}',
          404,
        ),
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

DailyContentRepository _repo(SupabaseStub stub, {FakeCacheService? cache}) =>
    DailyContentRepository(
      api: stub.api(cache: cache),
      clock: () => _now,
    );

Future<DailyContent?> _content(List<Map<String, dynamic>> rows) =>
    _repo(SupabaseStub({'daily_entries': rows})).watchTodaysContent().last;

Future<DailyMessage?> _message(List<Map<String, dynamic>> rows) =>
    _repo(SupabaseStub({'daily_messages': rows})).watchTodaysMessage().last;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('reading and prayer', () {
    test('today\u2019s reading and prayer, app workspace first', () async {
      final content = await _content([
        _entry(workspace: 'general', title: 'Shared reading'),
        _entry(),
        _entry(kind: 'prayer', workspace: 'general', title: 'Shared prayer'),
        _entry(kind: 'prayer', title: 'App prayer', reference: 'Psalm 5:3'),
      ]);
      expect(content?.reading?.title, 'God so loved');
      expect(content?.reading?.reference, 'John 3:16-18');
      expect(content?.reading?.body, 'Read it slowly.');
      expect(content?.prayer?.title, 'App prayer');
      expect(content?.prayer?.reference, 'Psalm 5:3');
    });

    test('the general workspace fills in for the app one', () async {
      final content = await _content([
        _entry(workspace: 'general', body: null, reference: null),
        _entry(kind: 'prayer', title: '  '),
      ]);
      expect(content?.reading?.title, 'God so loved');
      expect(content?.reading?.body, isEmpty);
      expect(content?.reading?.reference, isEmpty);
      expect(content?.prayer, isNull, reason: 'no prayer without a title');
    });

    test('a prayer alone is still today\u2019s content', () async {
      final content = await _content([_entry(kind: 'prayer')]);
      expect(content?.reading, isNull);
      expect(content?.prayer?.title, 'God so loved');
    });

    test('other workspaces, other days and undated rows are nothing', () async {
      expect(await _content(const []), isNull);
      expect(
        await _content([
          _entry(workspace: 'kharis'),
          _entry(workspace: 'kp2', kind: 'prayer'),
          _entry(date: '2026-10-15'),
          _entry(date: null),
          _entry(kind: 'devotional'),
        ]),
        isNull,
      );
    });

    test('asks for today in the app workspaces', () async {
      final stub = SupabaseStub({'daily_entries': []});
      await _repo(stub).watchTodaysContent().last;
      final query = stub.requests.single.uri.queryParameters;
      expect(stub.requests.single.uri.path, endsWith('/daily_entries'));
      expect(query['date'], 'eq.$_today');
      expect(query['workspace'], 'in.(app,general)');
    });

    test('a table the Studio does not have yet is nothing, not an error', () {
      final stub = _Studio(const {}, missing: {'daily_entries'});
      expect(_repo(stub).watchTodaysContent().toList(), completion([null]));
    });

    test('offline with nothing saved is an error', () {
      final stub = SupabaseStub({'daily_entries': []})..offline = true;
      expect(_repo(stub).watchTodaysContent().toList(), throwsA(anything));
    });

    test('offline shows the copy saved by the last good fetch', () async {
      final stub = SupabaseStub({
        'daily_entries': [_entry()],
      });
      final cache = FakeCacheService();
      await _repo(stub, cache: cache).watchTodaysContent().last;

      stub.offline = true;
      final emitted = await _repo(
        stub,
        cache: cache,
      ).watchTodaysContent().toList();
      expect(emitted.map((c) => c?.reading?.title), ['God so loved']);
    });
  });

  group('daily message', () {
    test('today\u2019s row names the sermon and carries the note', () async {
      final m = await _message([
        {'id': 'm0', 'date': '2026-10-15', 'sermon_id': 'yesterday'},
        {'id': 'm1', 'date': _today, 'sermon_id': ' ', 'note': 'x'},
        {'id': 'm2', 'date': _today, 'sermon_id': 's1', 'note': 'Listen.'},
      ]);
      expect(m?.sermonId, 's1');
      expect(m?.note, 'Listen.');
    });

    test('no row, or a missing table or column, is no message', () async {
      expect(await _message(const []), isNull);
      final stub = _Studio(const {}, missing: {'daily_messages'});
      expect(await _repo(stub).watchTodaysMessage().toList(), [null]);
    });
  });

  group('Home cards', () {
    const sermon = Sermon(
      id: 's1',
      title: 'Light for the path',
      speaker: 'Pastor',
      audioUrl: 'https://example.org/a.mp3',
    );

    Future<void> pump(
      WidgetTester tester,
      Widget card,
      List<Override> overrides,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: overrides,
          child: MaterialApp(
            home: Scaffold(body: Column(children: [card])),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the reading card hides, padding included, with nothing '
        'today or a failed load', (tester) async {
      for (final content in [
        Stream<DailyContent?>.value(null),
        Stream<DailyContent?>.error(Exception('offline')),
      ]) {
        await pump(
          tester,
          const TodaysReadingCard(padding: EdgeInsets.all(20)),
          [dailyContentProvider.overrideWith((ref) => content)],
        );
        expect(tester.getSize(find.byType(TodaysReadingCard)).height, 0);
      }
    });

    testWidgets('the reading card shows the entries; no prayer, no section', (
      tester,
    ) async {
      await pump(tester, const TodaysReadingCard(), [
        dailyContentProvider.overrideWith(
          (ref) => Stream.value(
            const DailyContent(
              reading: DailyEntry(
                title: 'God so loved',
                reference: 'John 3:16-18',
                body: 'Read it slowly.',
              ),
            ),
          ),
        ),
      ]);
      expect(find.text('God so loved'), findsOneWidget);
      expect(find.text('John 3:16-18'), findsOneWidget);
      expect(find.text('Read it slowly.'), findsOneWidget);
      expect(find.textContaining('DAILY PRAYER'), findsNothing);
      expect(find.text('Read now'), findsOneWidget);
    });

    testWidgets('the message card shows its sermon and note, and hides '
        'while the sermon is unknown', (tester) async {
      const message = DailyMessage(sermonId: 's1', note: 'Listen today.');

      await pump(tester, const DailyMessageCard(padding: EdgeInsets.all(20)), [
        dailyMessageProvider.overrideWith((ref) => Stream.value(message)),
        sermonByIdProvider.overrideWith(
          (ref, id) => const AsyncData<Sermon?>(null),
        ),
      ]);
      expect(tester.getSize(find.byType(DailyMessageCard)).height, 0);

      await pump(tester, const DailyMessageCard(), [
        dailyMessageProvider.overrideWith((ref) => Stream.value(message)),
        sermonByIdProvider.overrideWith(
          (ref, id) => AsyncData<Sermon?>(id == 's1' ? sermon : null),
        ),
      ]);
      expect(find.text('Light for the path'), findsOneWidget);
      expect(find.text('Listen today.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-daily-message')),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no message today hides the message card', (tester) async {
      await pump(tester, const DailyMessageCard(padding: EdgeInsets.all(20)), [
        dailyMessageProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      expect(tester.getSize(find.byType(DailyMessageCard)).height, 0);
    });
  });
}
