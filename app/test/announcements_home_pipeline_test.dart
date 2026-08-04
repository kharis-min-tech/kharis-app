import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:dio/dio.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/home/data/kharis_api_announcement_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/news_section.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// End-to-end proof of the homepage announcements pipeline with only the
/// network stubbed: getAnnouncements JSON (the live kharis-church response
/// shape) → [KharisApiAnnouncementRepository] → [newsProvider] (expiry
/// filter) → [AnnouncementsCarousel] on the home screen.
///
/// Seed data matches backend/functions/scripts/seed-announcements.mjs, so
/// these tests prove exactly what a member sees after that script runs.

/// Serves canned getAnnouncements JSON and records every request, so tests
/// can assert both what rendered and what the app asked the API for.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.announcements);

  final List<Map<String, dynamic>> announcements;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Same envelope as the live endpoint.
    final body = jsonEncode({
      'announcements': announcements,
      'count': announcements.length,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Fails every request, forcing the repository onto its Firestore fallback.
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The live payload shape returned by
/// getAnnouncements on kharis-church, seeded by seed-announcements.mjs.
Map<String, dynamic> _announcementJson({
  String id = 'welcome-new-app',
  String title = 'Welcome to the new Kharis app',
  String? expiresAt,
}) =>
    {
      'id': id,
      'title': title,
      'body': 'Announcements from your campus now appear here — stay tuned.',
      'type': 'Announcement',
      'branch': null,
      'imageUrl': null,
      'publishedAt': '2026-08-04T20:19:05.000Z',
      'expiresAt': expiresAt,
    };

KharisApiAnnouncementRepository _repository(HttpClientAdapter adapter) =>
    KharisApiAnnouncementRepository(
      dio: Dio()..httpClientAdapter = adapter,
      fallback: NewsRepository(firestore: FakeFirebaseFirestore()),
    );

Widget _homeHarness(
  KharisApiAnnouncementRepository repository, {
  String? branch,
}) {
  return ProviderScope(
    overrides: [
      announcementApiRepositoryProvider.overrideWithValue(repository),
      currentBranchProvider.overrideWith((ref) => Stream.value(branch)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: AnnouncementsCarousel()),
    ),
  );
}

/// [currentBranchProvider]'s emission (and the Firestore fallback stream)
/// land on microtasks that schedule no frame while `pumpAndSettle` is
/// polling; the extra pump picks them up, the final settle renders the
/// resulting fetch.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('repository maps the live getAnnouncements JSON onto NewsItem',
      () async {
    final repo = _repository(
      _StubAdapter([_announcementJson(expiresAt: '2036-01-01T00:00:00.000Z')]),
    );

    final items = await repo.getAnnouncements();

    final item = items.single;
    expect(item.id, 'welcome-new-app');
    expect(item.title, 'Welcome to the new Kharis app');
    expect(item.type, 'Announcement');
    expect(item.branch, isNull);
    expect(item.publishedAt.toUtc().year, 2026);
    expect(item.expiresAt?.toUtc().year, 2036);
    expect(item.isExpired, isFalse);
  });

  testWidgets('seeded announcements render on the homepage carousel',
      (tester) async {
    final adapter = _StubAdapter([
      _announcementJson(),
      _announcementJson(
        id: 'messages-on-the-go',
        title: 'Listen to messages on the go',
      ),
    ]);
    await tester.pumpWidget(_homeHarness(_repository(adapter)));
    await _settle(tester);

    expect(find.text('Welcome to the new Kharis app'), findsOneWidget);
    expect(find.text('Listen to messages on the go'), findsOneWidget);
    expect(find.text('No announcements'), findsNothing);
  });

  testWidgets('expired announcements never reach the carousel',
      (tester) async {
    final adapter = _StubAdapter([
      _announcementJson(),
      _announcementJson(
        id: 'lapsed',
        title: 'Old expired notice',
        expiresAt: '2020-01-01T00:00:00.000Z',
      ),
    ]);
    await tester.pumpWidget(_homeHarness(_repository(adapter)));
    await _settle(tester);

    expect(find.text('Welcome to the new Kharis app'), findsOneWidget);
    expect(find.text('Old expired notice'), findsNothing);
  });

  testWidgets('member branch is forwarded to the API for server-side scoping',
      (tester) async {
    final adapter = _StubAdapter([_announcementJson()]);
    await tester.pumpWidget(
      _homeHarness(_repository(adapter), branch: 'london-hq'),
    );
    await _settle(tester);

    expect(
      adapter.requests.last.queryParameters['branch'],
      'london-hq',
      reason: 'scoping is server-side: the app must not re-filter by branch',
    );
    expect(find.text('Welcome to the new Kharis app'), findsOneWidget);
  });

  // Plain test zone: watchNews's stream never delivers under flutter_test's
  // FakeAsync zone, so the offline path is proven at the repository boundary.
  // The carousel rendering of repository output is covered by the widget
  // tests above — together they cover API-down → fallback → homepage.
  test('API down → repository serves the Firestore fallback', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('news').doc('welcome-new-app').set({
      'title': 'Welcome to the new Kharis app',
      'body': 'Announcements from your campus now appear here — stay tuned.',
      'type': 'Announcement',
      'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 4)),
    });
    final repo = KharisApiAnnouncementRepository(
      dio: Dio()..httpClientAdapter = _OfflineAdapter(),
      fallback: NewsRepository(firestore: firestore),
    );

    final items = await repo.getAnnouncements();

    expect(items.single.title, 'Welcome to the new Kharis app');
    expect(items.single.isExpired, isFalse);
  });

  testWidgets('empty feed shows the quiet empty state', (tester) async {
    await tester.pumpWidget(_homeHarness(_repository(_StubAdapter([]))));
    await _settle(tester);

    expect(find.text('No announcements'), findsOneWidget);
  });
}
