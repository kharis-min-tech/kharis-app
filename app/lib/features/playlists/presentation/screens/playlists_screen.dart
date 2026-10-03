import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/favorites_tile.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// The member's playlist library: their own categorisations only, streamed
/// from `users/{uid}/playlists` so they survive relaunch and follow the
/// account. Favorites is pinned above them as a distinct tile and opens its
/// own screen; it never appears among the playlists.
///
/// Always reached as a pushed route over the shell (`/playlists`), so the
/// AppBar back button (and system back) return to whatever was underneath;
/// this screen never replaces a tab's content.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(playlistRepositoryProvider);
    if (!repo.hasUser) {
      // Retry the anonymous sign-in so "try again shortly" is honest even
      // when the launch-time attempt failed (offline first run).
      ref.read(anonymousSignInProvider).ensure();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still signing you in. Try again in a moment.'),
        ),
      );
      return;
    }
    final name = await showPlaylistNameDialog(context, title: 'New playlist');
    if (name == null || !context.mounted) return;
    final id = repo.create(name);
    context.push('/playlists/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.kc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Left-aligned on every platform with a compact icon action: a
        // centred title collided with a wide "New playlist" pill on narrow
        // iPhones. The toolbar sizes the title to the space the action
        // leaves, and one line plus an ellipsis keeps it there at any text
        // scale. The empty state carries the labelled "New playlist" CTA.
        centerTitle: false,
        title: Text(
          'Playlists',
          key: const ValueKey('playlists-title'),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.display(
            size: 26,
            weight: FontWeight.w700,
            color: context.kc.onBg,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton.filled(
              key: const ValueKey('playlists-new'),
              tooltip: 'New playlist',
              onPressed: () => _createPlaylist(context, ref),
              style: IconButton.styleFrom(
                backgroundColor: context.kc.accent,
                foregroundColor: context.kc.onAccent,
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: FavoritesTile(onTap: () => context.push('/favorites')),
            ),
          ),
          ...playlistsAsync.when(
            loading: () => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.kc.accentInk,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ],
            error: (_, _) => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  headline: "Your playlists couldn't be loaded",
                  body: 'Check your connection and try again.',
                  onCreate: null,
                ),
              ),
            ],
            data: (playlists) => playlists.isEmpty
                ? [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        icon: Icons.queue_music_rounded,
                        headline: 'Build your first playlist',
                        body:
                            'Group messages your way, by theme, season or '
                            'series. They save to your account and are '
                            'waiting after every relaunch.',
                        onCreate: () => _createPlaylist(context, ref),
                      ),
                    ),
                  ]
                : _playlistGrid(context, playlists),
          ),
        ],
      ),
    );
  }
}

// ── Grid ──────────────────────────────────────────────────────────────────────

List<Widget> _playlistGrid(BuildContext context, List<Playlist> playlists) => [
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Text(
        'Made by you · synced to your account',
        style: AppTypography.bodySm.copyWith(
          fontSize: 13,
          color: context.kc.muted,
        ),
      ),
    ),
  ),
  SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final playlist = playlists[index];
        return PlaylistCard(
          playlist: playlist,
          onTap: () => context.push('/playlists/${playlist.id}'),
        );
      }, childCount: playlists.length),
    ),
  ),
];

// ── Empty / error state ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.headline,
    required this.body,
    required this.onCreate,
  });

  final IconData icon;
  final String headline;
  final String body;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: context.kc.muted),
            const SizedBox(height: 18),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: AppTypography.display(
                size: 20,
                weight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                fontSize: 14,
                height: 1.5,
                color: context.kc.muted,
              ),
            ),
            if (onCreate != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: context.kc.accent,
                  foregroundColor: context.kc.onAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'New playlist',
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: context.kc.onAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
