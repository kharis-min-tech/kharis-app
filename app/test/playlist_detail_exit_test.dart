import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlists_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Regression guard for the "playlist view overtakes the page and cannot be
/// exited" complaint: every playlist surface is a *pushed* route with a
/// standard AppBar back button, and popping lands back on the route beneath.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final member = User(
    id: 'member-1',
    email: 'member@kharis.org',
    displayName: 'Member',
    role: 'member',
    createdAt: DateTime(2024),
  );

  Future<FakeFirebaseFirestore> seededDb() async {
    final db = FakeFirebaseFirestore();
    final now = Timestamp.fromDate(DateTime(2026, 8, 1));
    await db
        .collection('users')
        .doc('member-1')
        .collection('playlists')
        .doc('p1')
        .set({
          'name': 'Deep Roots',
          'sermonIds': ['s1'],
          'createdAt': now,
          'updatedAt': now,
        });
    return db;
  }

  List<Override> overridesFor(FakeFirebaseFirestore db) => [
    firestoreProvider.overrideWithValue(db),
    currentUserProvider.overrideWith((ref) => Stream.value(member)),
    sermonsProvider.overrideWith(
      (ref) async => [
        Sermon(
          id: 's1',
          title: 'Walking in Faith',
          speaker: 'Pastor A',
          audioUrl: 'https://audio.example/s1.mp3',
        ),
      ],
    ),
    currentSermonProvider.overrideWith((ref) => null),
    playerStateProvider.overrideWith(
      (ref) => const Stream<PlayerState>.empty(),
    ),
  ];

  GoRouter routerFor() => GoRouter(
    initialLocation: '/playlists',
    routes: [
      GoRoute(
        path: '/playlists',
        builder: (context, state) => const PlaylistsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                PlaylistDetailScreen(playlistId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );

  testWidgets('playlist detail is a pushed route whose back button pops home', (
    tester,
  ) async {
    final db = await seededDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(db),
        child: MaterialApp.router(routerConfig: routerFor()),
      ),
    );
    await tester.pumpAndSettle();

    // Playlists home shows the member's playlist.
    expect(find.text('Deep Roots'), findsOneWidget);
    expect(find.text('Play all'), findsNothing);

    // Open the detail — a push, so home stays on the stack beneath.
    await tester.tap(find.text('Deep Roots'));
    await tester.pumpAndSettle();
    expect(find.text('Play all'), findsOneWidget);
    expect(find.text('Walking in Faith'), findsOneWidget);

    // The standard AppBar back affordance exists and pops to the home.
    final back = find.byType(BackButton);
    expect(back, findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.text('Play all'), findsNothing);
    expect(find.text('Deep Roots'), findsOneWidget); // home again
  });

  testWidgets('a deleted / unknown playlist renders an exitable fallback', (
    tester,
  ) async {
    final db = await seededDb();
    final router = routerFor();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(db),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/playlists/does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('This playlist no longer exists.'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Deep Roots'), findsOneWidget);
  });
}
