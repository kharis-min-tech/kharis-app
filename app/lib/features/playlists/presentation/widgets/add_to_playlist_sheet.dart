import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/collection_labels.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_scaffold.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Bottom sheet that files a message into the member's collections.
///
/// Rows toggle membership live (a check = already in that collection), so a
/// message can be added to several collections in one visit. "New
/// collection" creates one and files the message in it immediately.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required String sermonId,
  required String sermonTitle,
  VoidCallback? onOpenNotes,
}) {
  return showKBottomSheet<void>(
    context: context,
    title: 'Add to collection',
    builder: (_) => AddToPlaylistSheet(
      sermonId: sermonId,
      sermonTitle: sermonTitle,
      onOpenNotes: onOpenNotes,
    ),
  );
}

class AddToPlaylistSheet extends ConsumerWidget {
  const AddToPlaylistSheet({
    super.key,
    required this.sermonId,
    required this.sermonTitle,
    this.onOpenNotes,
  });

  final String sermonId;
  final String sermonTitle;

  /// Opens this message's notes without playing it; null hides the row.
  final VoidCallback? onOpenNotes;

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(playlistRepositoryProvider);
    final name = await showPlaylistNameDialog(context, title: 'New collection');
    if (name == null || !repo.hasUser) return;
    final playlistId = repo.create(name);
    repo.addSermon(playlistId, sermonId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final repo = ref.watch(playlistRepositoryProvider);
    if (!repo.hasUser) {
      // Kick another anonymous sign-in attempt so "try again in a moment"
      // stays honest even when the launch-time attempt failed (offline first
      // run): closing and reopening this sheet retries. Single-flight, so
      // rebuilds never stack sign-in calls.
      ref.read(anonymousSignInProvider).ensure();
    }
    final playlistsAsync = ref.watch(playlistsProvider);
    final playlists = playlistsAsync.valueOrNull ?? const <Playlist>[];
    final loading = playlistsAsync.isLoading && playlists.isEmpty;

    final rows = <Widget>[
      if (onOpenNotes != null)
        KListRow(
          key: const Key('sheet-open-notes'),
          title: 'My notes',
          leading: const KIconTile(KIcons.note),
          showChevron: true,
          onTap: () {
            Navigator.of(context).pop();
            onOpenNotes!();
          },
        ),
      if (repo.hasUser) ...[
        KListRow(
          title: 'New collection',
          leading: const KIconTile(KIcons.plus),
          onTap: () => _createAndAdd(context, ref),
        ),
        if (!loading)
          for (final playlist in playlists)
            _CollectionOption(
              playlist: playlist,
              isIn: playlist.contains(sermonId),
              onTap: () {
                if (playlist.contains(sermonId)) {
                  repo.removeSermon(playlist.id, sermonId);
                } else {
                  repo.addSermon(playlist.id, sermonId);
                }
              },
            ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          sermonTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KharisText.meta.copyWith(color: k.muted),
        ),
        const SizedBox(height: KSpace.xl),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rows.isNotEmpty) KListGroup(children: rows),
                if (!repo.hasUser) ...[
                  const SizedBox(height: KSpace.xl),
                  Text(
                    'Still signing you in. Try again in a moment.',
                    style: KharisText.meta.copyWith(color: k.muted),
                  ),
                ] else if (loading) ...[
                  const SizedBox(height: KSpace.xl),
                  const LibraryListSkeleton(rows: 2),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: KSpace.xl),
        KButton(
          label: 'Done',
          variant: KButtonVariant.text,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// One collection in the sheet: a check marks the collections the message
/// is already in, and the state is announced, never shown by colour alone.
class _CollectionOption extends StatelessWidget {
  const _CollectionOption({
    required this.playlist,
    required this.isIn,
    required this.onTap,
  });

  final Playlist playlist;
  final bool isIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isIn,
      child: KListRow(
        title: playlist.name,
        meta: messageCountLabel(playlist.sermonIds.length),
        leading: PlaylistArt(playlist: playlist),
        trailing: isIn
            ? KIcon(KIcons.check, color: context.k.primaryText)
            : null,
        onTap: onTap,
      ),
    );
  }
}
