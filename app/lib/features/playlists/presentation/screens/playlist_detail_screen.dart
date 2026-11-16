import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/collection_labels.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/collection_message_row.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_scaffold.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_sheets.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/ui/components/components.dart';

enum _PlaylistAction { rename, delete }

/// One collection: its messages resolved against the loaded catalogue, with
/// rename / delete / remove-message management.
///
/// Reached only as a pushed route (`/playlists/:id`), so swipe back and the
/// system back pop to the collections home, never trapping the member.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  Future<void> _showOptions(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final action = await showKBottomSheet<_PlaylistAction>(
      context: context,
      title: playlist.name,
      builder: (sheetContext) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KListGroup(
              children: [
                KListRow(
                  title: 'Rename',
                  leading: const KIconTile(KIcons.pen),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_PlaylistAction.rename),
                ),
                KListRow(
                  title: 'Delete collection',
                  leading: const KIconTile(KIcons.close),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_PlaylistAction.delete),
                ),
              ],
            ),
            const SizedBox(height: KSpace.xl),
            KButton(
              label: 'Cancel',
              variant: KButtonVariant.text,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _PlaylistAction.rename:
        await _rename(context, ref, playlist);
      case _PlaylistAction.delete:
        await _confirmDelete(context, ref, playlist);
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Rename collection',
      initialName: playlist.name,
      confirmLabel: 'Save',
    );
    if (name == null) return;
    ref.read(playlistRepositoryProvider).rename(playlist.id, name);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Delete collection?',
      message:
          '"${playlist.name}" will be removed from your library. '
          'The messages themselves are untouched.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    ref.read(playlistRepositoryProvider).deletePlaylist(playlist.id);
    Navigator.of(context).maybePop();
  }

  Future<void> _removeSermon(
    BuildContext context,
    WidgetRef ref,
    Sermon sermon,
  ) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Remove from this collection?',
      message: sermon.title,
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    ref.read(playlistRepositoryProvider).removeSermon(playlistId, sermon.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final playlist = ref.watch(playlistByIdProvider(playlistId));
    final playlistsAsync = ref.watch(playlistsProvider);

    if (playlist == null) {
      return LibraryScaffold(
        title: 'Collection',
        slivers: [
          if (playlistsAsync.isLoading)
            const LibrarySection(child: LibraryListSkeleton())
          else
            LibraryFill(
              child: KEmptyState(
                icon: KIcons.collection,
                title: 'This collection no longer exists',
                hint: 'Go back to see the collections you have.',
                action: KButton(
                  label: 'See collections',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
        ],
      );
    }

    final resolution = ref.watch(playlistResolutionProvider(playlistId));
    final sermons = resolution.sermons;
    final missing = resolution.missing;

    return LibraryScaffold(
      title: playlist.name,
      actions: [
        KIconButton(
          key: const Key('playlist-options'),
          icon: KIcons.gear,
          label: 'Collection options',
          onPressed: () => _showOptions(context, ref, playlist),
        ),
      ],
      slivers: [
        LibrarySection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PlaylistArt(playlist: playlist, size: KSize.artwork),
                  const SizedBox(width: KSpace.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          collectionMeta(sermons.length, resolution),
                          style: KharisText.meta.copyWith(color: k.muted),
                        ),
                        if (missing > 0)
                          Text(
                            missing == 1
                                ? '1 saved message is no longer in the library'
                                : '$missing saved messages are no longer in '
                                      'the library',
                            style: KharisText.meta.copyWith(color: k.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // An empty collection has nothing to play: no dead button
              // above the empty state, which says how to add messages.
              if (sermons.isNotEmpty) ...[
                const SizedBox(height: KSpace.x3),
                KButton(
                  key: const Key('playlist-play-all'),
                  label: 'Play',
                  icon: KIcons.play,
                  expand: true,
                  onPressed: () => startPlayback(
                    context,
                    ref,
                    sermons.first,
                    queue: sermons,
                  ),
                ),
                const SizedBox(height: KSpace.x3),
                KListGroup(
                  children: [
                    for (final sermon in sermons)
                      CollectionMessageRow(
                        key: ValueKey(sermon.id),
                        sermon: sermon,
                        removeLabel:
                            'Remove ${sermon.title} from this collection',
                        onTap: () =>
                            startPlayback(context, ref, sermon, queue: sermons),
                        onRemove: () => _removeSermon(context, ref, sermon),
                      ),
                  ],
                ),
              ] else if (resolution.pending > 0) ...[
                const SizedBox(height: KSpace.x3),
                const LibraryListSkeleton(),
              ],
            ],
          ),
        ),
        if (sermons.isEmpty && playlist.sermonIds.isEmpty)
          LibraryFill(
            child: KEmptyState(
              icon: KIcons.collection,
              title: 'Nothing here yet',
              hint: 'Add messages to this collection from the Messages tab.',
              action: KButton(
                label: 'Browse messages',
                onPressed: () => context.go('/messages'),
              ),
            ),
          ),
      ],
    );
  }
}
