import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/news_section.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_cache_service.dart';
import 'support/supabase_stub.dart';

/// The homepage announcements pipeline with only the network stubbed:
/// Content Studio `news` rows → [NewsRepository] → [newsProvider] →
/// [AnnouncementsCarousel].

final _past = DateTime.utc(2026, 8, 4).toIso8601String();
const _future = '2036-01-01T00:00:00Z';

Map<String, dynamic> _row({
  String id = 'welcome',
  String title = 'Welcome to the new Kharis app',
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'title': title,
  'workspace': 'app',
  'created_at': _past,
  ...extra,
};

Widget _homeHarness(SupabaseStub stub, {String? branch}) {
  return ProviderScope(
    overrides: [
      newsRepositoryProvider.overrideWithValue(NewsRepository(api: stub.api())),
      currentBranchProvider.overrideWith((ref) => Stream.value(branch)),
    ],
    child: const MaterialApp(home: Scaffold(body: AnnouncementsCarousel())),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('NewsRepository mapping', () {
    test('only Mobile App and General announcements reach the app', () {
      final live = NewsRepository.liveFor([
        _row(id: 'app'),
        _row(id: 'general', extra: {'workspace': 'general'}),
        _row(id: 'kharis', extra: {'workspace': 'kharis'}),
        _row(id: 'kp2', extra: {'workspace': 'kp2'}),
        _row(id: 'none', extra: {'workspace': null}),
      ], branch: null);
      expect(live.map((n) => n.id), unorderedEquals(['app', 'general']));
    });

    test('reads every known column name and filters bad image URLs', () {
      final item = NewsRepository.fromRow(
        _row(
          extra: {
            'content': 'Body text',
            'image_url': 'assets/design/city-brighton.jpg',
            'branch_name': ' ',
            'expires_at': _future,
            'status': 'published',
            'link_url': 'https://kharis.org/x',
            'cta_label': 'Read',
          },
        ),
      )!;

      expect(item.id, 'welcome');
      expect(item.body, 'Body text');
      expect(item.imageUrl, isNull, reason: 'app paths are not usable');
      expect(item.branch, isNull, reason: 'blank is all branches');
      expect(item.expiresAt?.toUtc().year, 2036);
      expect(item.publishedAt.toUtc(), DateTime.utc(2026, 8, 4));
      expect(item.linkUrl, 'https://kharis.org/x');
      expect(item.ctaLabel, 'Read');
      expect(item.type, 'Announcement');
    });

    test('keeps https images and drops localhost ones', () {
      expect(
        NewsRepository.fromRow(
          _row(extra: {'image_url': 'https://cdn.kharis.org/a.jpg'}),
        )!.imageUrl,
        'https://cdn.kharis.org/a.jpg',
      );
      expect(
        NewsRepository.fromRow(
          _row(extra: {'image_url': 'http://localhost:3002/a.jpg'}),
        )!.imageUrl,
        isNull,
      );
    });

    test(
      'drafts, rows without a title, scheduled and expired are not live',
      () {
        final items = NewsRepository.liveFor([
          _row(id: 'ok'),
          _row(id: 'draft', extra: {'status': 'draft'}),
          {'id': 'untitled', 'created_at': _past},
          _row(id: 'scheduled', extra: {'published_at': _future}),
          _row(id: 'expired', extra: {'expires_at': _past}),
        ], branch: null);

        expect(items.map((n) => n.id), ['ok']);
      },
    );

    test('branch scoping: own branch plus all branches', () {
      final rows = [
        _row(id: 'all'),
        _row(id: 'london', extra: {'branch_name': 'London'}),
        _row(id: 'leeds', extra: {'branch_name': 'Leeds'}),
      ];

      expect(
        NewsRepository.liveFor(rows, branch: 'London').map((n) => n.id),
        unorderedEquals(['all', 'london']),
      );
      expect(NewsRepository.liveFor(rows, branch: null), hasLength(3));
    });

    test('asks for the newest first, bounded', () async {
      final stub = SupabaseStub({'news': []});
      await NewsRepository(api: stub.api()).getAnnouncements();
      final query = stub.requests.single.uri.queryParameters;
      expect(
        query['order'],
        'published_at.desc.nullslast,created_at.desc,id.desc',
      );
      expect(query['limit'], '100');
    });

    test('an empty table is an empty list', () async {
      final repo = NewsRepository(api: SupabaseStub({'news': []}).api());
      expect(await repo.getAnnouncements(), isEmpty);
    });

    test('offline serves the copy saved by the last good fetch', () async {
      final stub = SupabaseStub({
        'news': [_row()],
      });
      final repo = NewsRepository(api: stub.api(cache: FakeCacheService()));
      final cache = FakeCacheService();
      final cached = NewsRepository(api: stub.api(cache: cache));
      await cached.getAnnouncements();

      stub.offline = true;

      expect(
        (await cached.getAnnouncements()).single.title,
        'Welcome to the new Kharis app',
      );
      await expectLater(repo.getAnnouncements(), throwsA(anything));
    });
  });

  testWidgets('Studio announcements render on the homepage carousel', (
    tester,
  ) async {
    final stub = SupabaseStub({
      'news': [
        _row(),
        _row(id: 'go', title: 'Listen to messages on the go'),
        _row(
          id: 'old',
          title: 'Old expired notice',
          extra: {'expires_at': _past},
        ),
      ],
    });
    await tester.pumpWidget(_homeHarness(stub));
    await _settle(tester);

    expect(find.text('Welcome to the new Kharis app'), findsOneWidget);
    expect(find.text('Listen to messages on the go'), findsOneWidget);
    expect(find.text('Old expired notice'), findsNothing);
    expect(
      stub.requests.single.headers['apikey'],
      isNotEmpty,
      reason: 'Supabase needs the publishable key',
    );
  });

  testWidgets('another branch\'s announcement stays off the carousel', (
    tester,
  ) async {
    final stub = SupabaseStub({
      'news': [
        _row(
          id: 'mine',
          title: 'London notice',
          extra: {'branch_name': 'London'},
        ),
        _row(
          id: 'theirs',
          title: 'Leeds notice',
          extra: {'branch_name': 'Leeds'},
        ),
      ],
    });
    await tester.pumpWidget(_homeHarness(stub, branch: 'London'));
    await _settle(tester);

    expect(find.text('London notice'), findsOneWidget);
    expect(find.text('Leeds notice'), findsNothing);
  });

  testWidgets('empty table renders nothing (Home hides the block)', (
    tester,
  ) async {
    await tester.pumpWidget(_homeHarness(SupabaseStub({'news': []})));
    await _settle(tester);

    expect(find.textContaining('No announcements'), findsNothing);
    expect(find.byKey(const Key('announcements-skeleton')), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });
}
