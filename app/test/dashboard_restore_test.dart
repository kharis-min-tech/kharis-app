import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// Records the launch-time restore.
class _RestoringAudio extends FakeAudioPlayerService {
  final List<Sermon> restored = [];

  @override
  Future<void> loadPaused(Sermon sermon) async {
    restored.add(sermon);
    current = sermon;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Last played as a YouTube feed entry: an id the hydrated archive never
  // carries, so only the snapshot can place it before the catalogue loads.
  const lastPlayed = Sermon(
    id: 'vid9',
    title: 'Grace Over Guilt',
    speaker: 'Pastor A',
    audioUrl: 'https://cdn.example/grace.mp3',
    videoId: 'vid9',
  );

  final member = User(
    id: 'member-1',
    email: 'member@kharis.org',
    displayName: 'Member',
    role: 'member',
    branch: 'London',
    createdAt: DateTime(2024),
  );

  Future<_RestoringAudio> launch(
    WidgetTester tester, {
    required AsyncValue<Sermon?> lookup,
  }) async {
    SharedPreferences.setMockInitialValues({'branch_prompt_shown': true});
    final prefs = await SharedPreferences.getInstance();
    final audio = _RestoringAudio();
    final cache = FakeCacheService();
    PlaybackHistory(cache).recordPlay(lastPlayed);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              DashboardShell(navigationShell: shell),
          branches: [
            for (final path in [
              '/home',
              '/messages',
              '/giving',
              '/calendar',
              '/more',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (_, _) => Center(child: Text('page $path')),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioPlayerServiceProvider.overrideWithValue(audio),
          cacheServiceProvider.overrideWithValue(cache),
          sermonByIdProvider.overrideWith((ref, id) => lookup),
          currentUserProvider.overrideWith((ref) => Stream.value(member)),
          currentBranchProvider.overrideWith((ref) => Stream.value('London')),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return audio;
  }

  testWidgets(
    'restores the mini player from the snapshot while the archive is still '
    'hydrating',
    (tester) async {
      // The catalogue never settles during the test: the archive is filling.
      final audio = await launch(tester, lookup: const AsyncLoading());
      await tester.pump(const Duration(seconds: 1));
      expect(audio.restored, isEmpty, reason: 'still giving the lookup time');

      await tester.pump(const Duration(seconds: 5));

      expect(audio.restored.map((s) => s.id), ['vid9']);
      expect(audio.restored.single.audioUrl, lastPlayed.audioUrl);
    },
  );

  testWidgets('a catalogue hit restores at once with the catalogue sermon', (
    tester,
  ) async {
    final fresh = lastPlayed.copyWith(title: 'Grace Over Guilt (updated)');
    final audio = await launch(tester, lookup: AsyncData(fresh));
    await tester.pump(const Duration(milliseconds: 100));

    expect(audio.restored.single.title, 'Grace Over Guilt (updated)');
    await tester.pump(const Duration(seconds: 2));
  });
}
