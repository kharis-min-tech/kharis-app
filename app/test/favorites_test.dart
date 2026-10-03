import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart' show PlayerState;

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/like_button.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/screens/favorites_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlists_screen.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/favorites_tile.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// Favorites (the player's heart) live at `users/{uid}/playlists/liked` but
/// are not one of the member's playlists: they never show among them, have
/// their own screen, and play as their own queue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const uid = 'member-1';
  final member = User(
    id: uid,
    email: 'member@kharis.org',
    displayName: 'Member',
    role: 'member',
    createdAt: DateTime(2024),
  );

  Sermon sermon(int n) => Sermon(
    id: 's$n',
    title: 'Message $n',
    speaker: 'Pastor A',
    audioUrl: 'https://cdn.example/s$n.mp3',
  );
  final library = [for (var n = 1; n <= 4; n++) sermon(n)];

  CollectionReference<Map<String, dynamic>> playlistsOf(
    FakeFirebaseFirestore db,
  ) => db.collection('users').doc(uid).collection('playlists');

  /// A member with one playlist and a Favorites doc written by the older
  /// build (still named "Liked messages"), favorited in the order s1, s3, s2.
  Future<FakeFirebaseFirestore> seededDb({
    List<String> favorites = const ['s1', 's3', 's2'],
  }) async {
    final db = FakeFirebaseFirestore();
    final older = Timestamp.fromDate(DateTime(2026, 8, 1));
    final newer = Timestamp.fromDate(DateTime(2026, 9, 1));
    await playlistsOf(db).doc('p1').set({
      'name': 'Deep Roots',
      'sermonIds': ['s4'],
      'createdAt': older,
      'updatedAt': older,
    });
    await playlistsOf(db).doc(PlaylistRepository.favoritesId).set({
      'name': 'Liked messages',
      'sermonIds': favorites,
      'createdAt': newer,
      // Most recently touched, so it would sort first if it leaked through.
      'updatedAt': newer,
    });
    return db;
  }

  List<Override> overridesFor(FakeFirebaseFirestore db) => [
    firestoreProvider.overrideWithValue(db),
    currentUserProvider.overrideWith((ref) => Stream.value(member)),
    sermonsProvider.overrideWith((ref) async => library),
    videosProvider.overrideWith((ref) async => const <Sermon>[]),
    currentSermonProvider.overrideWith((ref) => null),
    playerStateProvider.overrideWith(
      (ref) => const Stream<PlayerState>.empty(),
    ),
  ];

  Future<List<String>?> storedFavorites(FakeFirebaseFirestore db) async {
    final snap = await playlistsOf(
      db,
    ).doc(PlaylistRepository.favoritesId).get();
    return (snap.data()?['sermonIds'] as List?)?.cast<String>();
  }

  group('Favorites are not a playlist', () {
    test('the playlists stream leaves Favorites out; '
        'favoritesProvider carries it', () async {
      final db = await seededDb();
      final container = ProviderContainer(overrides: overridesFor(db));
      addTearDown(container.dispose);
      container.listen(playlistsProvider, (_, _) {});
      container.listen(favoritesProvider, (_, _) {});

      for (var i = 0; i < 200; i++) {
        if (container.read(playlistsProvider).hasValue &&
            container.read(favoritesProvider).valueOrNull != null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final playlists = container.read(playlistsProvider).requireValue;
      expect(playlists.map((p) => p.id), ['p1']);
      final favorites = container.read(favoritesProvider).requireValue;
      expect(favorites?.id, PlaylistRepository.favoritesId);
      expect(favorites?.sermonIds, ['s1', 's3', 's2']);
    });

    testWidgets('the add-to-playlist sheet never lists Favorites', (
      tester,
    ) async {
      final db = await seededDb();
      final container = ProviderContainer(overrides: overridesFor(db));
      addTearDown(container.dispose);
      // The sheet opens from a live player, after auth has resolved.
      await tester.runAsync(() => container.read(currentUserProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AddToPlaylistSheet(
                sermonId: 's1',
                sermonTitle: 'Message 1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deep Roots'), findsOneWidget);
      expect(find.text('Liked messages'), findsNothing);
      expect(find.text('Favorites'), findsNothing);
      // Only the one real playlist is offered (plus the "New playlist" row).
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('Playlists pins a distinct Favorites tile above the grid, '
        'which lists only real playlists, and the tile opens /favorites', (
      tester,
    ) async {
      final db = await seededDb();
      final router = GoRouter(
        initialLocation: '/playlists',
        routes: [
          GoRoute(
            path: '/playlists',
            builder: (_, _) => const PlaylistsScreen(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (_, _) => const Scaffold(body: Text('route:/favorites')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(db),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistCard), findsOneWidget);
      expect(find.text('Deep Roots'), findsOneWidget);
      expect(find.text('Liked messages'), findsNothing);
      expect(find.byType(FavoritesTile), findsOneWidget);
      expect(find.text('3 messages'), findsOneWidget); // the tile's count
      expect(
        tester.getTopLeft(find.byType(FavoritesTile)).dy,
        lessThan(tester.getTopLeft(find.byType(PlaylistCard)).dy),
      );

      await tester.tap(find.byType(FavoritesTile));
      await tester.pumpAndSettle();
      expect(find.text('route:/favorites'), findsOneWidget);
    });

    testWidgets('with no playlists yet, the Favorites tile still leads and '
        'the empty state invites a first playlist', (tester) async {
      final db = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(db),
          child: const MaterialApp(home: PlaylistsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FavoritesTile), findsOneWidget);
      expect(find.byType(PlaylistCard), findsNothing);
      expect(find.text('Build your first playlist'), findsOneWidget);

      // The compact header action still creates a playlist.
      await tester.tap(find.byTooltip('New playlist'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('Favorites screen', () {
    testWidgets('lists favorites newest favorited first', (tester) async {
      final db = await seededDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(db),
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final y = [
        for (final title in ['Message 2', 'Message 3', 'Message 1'])
          tester.getTopLeft(find.text(title)).dy,
      ];
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
      // Not a playlist member: the playlist's own message is absent.
      expect(find.text('Message 4'), findsNothing);
    });

    testWidgets('empty state explains the heart', (tester) async {
      final db = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(db),
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No favorites yet'), findsOneWidget);
      expect(find.textContaining('tap the heart'), findsOneWidget);
      expect(find.text('Play all'), findsNothing);
    });

    testWidgets('a row plays with Favorites, in screen order, as the queue', (
      tester,
    ) async {
      MediaPlayerScreen.debugDisableVideoEngine = true;
      addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);
      final audio = FakeAudioPlayerService();
      final db = await seededDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            currentUserProvider.overrideWith((ref) => Stream.value(member)),
            sermonsProvider.overrideWith((ref) async => library),
            videosProvider.overrideWith((ref) async => const <Sermon>[]),
            audioPlayerServiceProvider.overrideWithValue(audio),
            cacheServiceProvider.overrideWithValue(FakeCacheService()),
            notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
          ],
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Message 3'));
      await tester.pumpAndSettle();

      final call = audio.calls.single;
      expect(call.sermon.id, 's3');
      expect(call.queue?.map((s) => s.id), ['s2', 's3', 's1']);
      expect(find.byType(MediaPlayerScreen), findsOneWidget);
    });

    testWidgets('swiping a row removes it from Favorites, and Undo restores '
        'it', (tester) async {
      final db = await seededDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(db),
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Message 3'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Message 3'), findsNothing);
      expect(find.text('Removed from Favorites'), findsOneWidget);
      expect(await tester.runAsync(() => storedFavorites(db)), ['s1', 's2']);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Message 3'), findsOneWidget);
      expect(await tester.runAsync(() => storedFavorites(db)), [
        's1',
        's2',
        's3',
      ]);
    });

    testWidgets('the ⋮ menu removes a row from Favorites', (tester) async {
      final db = await seededDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(db),
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Rows are newest first: the first ⋮ belongs to Message 2.
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from Favorites'));
      await tester.pumpAndSettle();

      expect(find.text('Message 2'), findsNothing);
      expect(await tester.runAsync(() => storedFavorites(db)), ['s1', 's3']);
    });

    testWidgets('hearting and unhearting in the player updates Favorites', (
      tester,
    ) async {
      final db = await seededDb(favorites: const ['s1']);
      // The player's heart and the Favorites screen share one account.
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(db),
          child: MaterialApp(
            home: Column(
              children: [
                Material(child: LikeButton(sermon: sermon(4))),
                const Expanded(child: FavoritesScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 4'), findsNothing);
      expect(find.byTooltip('Add to Favorites'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Message 4'), findsOneWidget);
      expect(find.text('2 messages · newest first'), findsOneWidget);
      // Newest favorited sits on top.
      expect(
        tester.getTopLeft(find.text('Message 4')).dy,
        lessThan(tester.getTopLeft(find.text('Message 1')).dy),
      );
      expect(find.byTooltip('Remove from Favorites'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Message 4'), findsNothing);
      expect(find.text('1 message · newest first'), findsOneWidget);
      expect(await tester.runAsync(() => storedFavorites(db)), ['s1']);
    });
  });

  group('Playlists header', () {
    for (final width in [375.0, 393.0]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          'title and the New playlist action never overlap at ${width.toInt()}pt '
          '(text x$textScale, iOS)',
          (tester) async {
            tester.view
              ..physicalSize = Size(width * 3, 852 * 3)
              ..devicePixelRatio = 3;
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            final db = await seededDb();
            final router = GoRouter(
              initialLocation: '/more',
              routes: [
                GoRoute(
                  path: '/more',
                  builder: (_, _) => const Scaffold(body: Text('More')),
                ),
                GoRoute(
                  path: '/playlists',
                  builder: (_, _) => const PlaylistsScreen(),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              ProviderScope(
                overrides: overridesFor(db),
                child: MaterialApp.router(routerConfig: router),
              ),
            );
            router.push('/playlists');
            await tester.pumpAndSettle();

            // Pushed over another route, as in the app: back button shows.
            expect(find.byType(BackButton), findsOneWidget);
            final title = tester.getRect(
              find.byKey(const ValueKey('playlists-title')),
            );
            final button = tester.getRect(
              find.byKey(const ValueKey('playlists-new')),
            );
            final back = tester.getRect(find.byType(BackButton));
            expect(
              title.overlaps(button),
              isFalse,
              reason: 'title $title overlaps button $button',
            );
            expect(title.overlaps(back), isFalse);
            expect(title.left, lessThan(button.left));
            // One line, with most of the bar to itself: the compact action
            // leaves the title room instead of squeezing it to a sliver.
            expect(title.height, lessThan(kToolbarHeight));
            expect(title.width, greaterThan(width / 2));
            expect(find.byTooltip('New playlist'), findsOneWidget);
            expect(button.right, lessThanOrEqualTo(width));
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  });
}
