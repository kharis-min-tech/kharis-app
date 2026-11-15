import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/playlists/presentation/widgets/favorites_tile.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_scaffold.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The member's collections: their own groupings of messages, streamed from
/// `users/{uid}/playlists` so they survive relaunch and follow the account.
/// Favourites is pinned above them as its own row and opens its own screen;
/// it never appears among the collections.
///
/// Always reached as a pushed route over the shell (`/playlists`), so swipe
/// back and the system back return to whatever was underneath; this screen
/// never replaces a tab's content.
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
    final name = await showPlaylistNameDialog(context, title: 'New collection');
    if (name == null || !context.mounted) return;
    final id = repo.create(name);
    context.push('/playlists/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return LibraryScaffold(
      title: 'Collections',
      titleKey: const ValueKey('playlists-title'),
      actions: [
        KIconButton(
          key: const ValueKey('playlists-new'),
          icon: KIcons.plus,
          label: 'New collection',
          variant: KIconButtonVariant.filled,
          onPressed: () => _createPlaylist(context, ref),
        ),
      ],
      slivers: [
        LibrarySection(
          child: FavoritesTile(onTap: () => context.push('/favorites')),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: KSpace.section)),
        ...playlistsAsync.when(
          loading: () => const [LibrarySection(child: LibraryListSkeleton())],
          error: (_, _) => [
            LibraryFill(
              child: KErrorState(
                message:
                    'Your collections didn\u2019t load. Check your '
                    'connection and retry.',
                onRetry: () => ref.invalidate(playlistsProvider),
              ),
            ),
          ],
          data: (playlists) => playlists.isEmpty
              ? [
                  LibraryFill(
                    child: KEmptyState(
                      icon: KIcons.collection,
                      title: 'Build your first collection',
                      hint:
                          'Group messages by theme, season or series. '
                          'Collections are saved to your account.',
                      action: KButton(
                        label: 'New collection',
                        icon: KIcons.plus,
                        onPressed: () => _createPlaylist(context, ref),
                      ),
                    ),
                  ),
                ]
              : [
                  LibrarySection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KSectionHeader(title: 'Your collections'),
                        KListGroup(
                          children: [
                            for (final playlist in playlists)
                              PlaylistCard(
                                playlist: playlist,
                                onTap: () =>
                                    context.push('/playlists/${playlist.id}'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
        ),
      ],
    );
  }
}
