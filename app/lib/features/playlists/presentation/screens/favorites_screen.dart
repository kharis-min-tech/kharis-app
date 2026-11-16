import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/collection_labels.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/collection_message_row.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_scaffold.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_sheets.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The member's Favourites: every message they hearted in the player, newest
/// favourited first, as a quick go-to separate from their collections.
///
/// Tapping a row plays it with Favourites (in this order) as the queue. A
/// row leaves by swiping it away or from its remove button, with an Undo.
///
/// Reached as a pushed route (`/favorites`) from More and the top of
/// Collections, so swipe back and the system back always exit.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  /// Ids removed here whose removal the snapshot has not reflected yet. A
  /// dismissed row must leave the tree on the very next frame, before the
  /// optimistic snapshot arrives, so they are hidden locally until then.
  final Set<String> _removing = {};

  void _remove(String id) {
    final repo = ref.read(playlistRepositoryProvider);
    if (!repo.hasUser) return;
    setState(() => _removing.add(id));
    repo.setLiked(id, liked: false, favoritesExist: true);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from Favourites'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (mounted) setState(() => _removing.remove(id));
              repo.setLiked(id, liked: true, favoritesExist: true);
            },
          ),
        ),
      );
  }

  Future<void> _confirmRemove(String id, Sermon sermon) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Remove from Favourites?',
      message: sermon.title,
      confirmLabel: 'Remove',
    );
    if (confirmed && mounted) _remove(id);
  }

  @override
  Widget build(BuildContext context) {
    // Forget a local removal once the snapshot confirms it, so a message
    // hearted again later (from the player above this screen) shows again.
    ref.listen(favoritesProvider, (_, next) {
      final ids = next.valueOrNull?.sermonIds ?? const <String>[];
      final confirmed = _removing.where((id) => !ids.contains(id)).toList();
      if (confirmed.isNotEmpty) _removing.removeAll(confirmed);
    });

    final favoritesAsync = ref.watch(favoritesProvider);
    final resolution = ref.watch(favoritesResolutionProvider);
    final ids = <String>[];
    final sermons = <Sermon>[];
    for (var i = 0; i < resolution.sermons.length; i++) {
      if (_removing.contains(resolution.ids[i])) continue;
      ids.add(resolution.ids[i]);
      sermons.add(resolution.sermons[i]);
    }
    final storedCount =
        favoritesAsync.valueOrNull?.sermonIds
            .where((id) => !_removing.contains(id))
            .length ??
        0;

    final Widget content;
    if ((favoritesAsync.isLoading && !favoritesAsync.hasValue) ||
        (resolution.pending > 0 && sermons.isEmpty)) {
      content = const LibrarySection(child: LibraryListSkeleton());
    } else if (favoritesAsync.hasError && !favoritesAsync.hasValue) {
      content = LibraryFill(
        child: KErrorState(
          message:
              'Your Favourites didn\u2019t load. Check your connection '
              'and retry.',
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
      );
    } else if (storedCount == 0) {
      content = LibraryFill(
        child: KEmptyState(
          icon: KIcons.heart,
          title: 'No Favourites yet',
          hint:
              'While a message plays, tap the heart beside its title to '
              'save it here.',
          action: KButton(
            label: 'Browse messages',
            onPressed: () => context.go('/messages'),
          ),
        ),
      );
    } else {
      content = LibrarySection(
        child: _FavoritesList(
          ids: ids,
          sermons: sermons,
          missing: resolution.missing,
          onRemove: _remove,
          onConfirmRemove: _confirmRemove,
        ),
      );
    }

    return LibraryScaffold(title: 'Favourites', slivers: [content]);
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({
    required this.ids,
    required this.sermons,
    required this.missing,
    required this.onRemove,
    required this.onConfirmRemove,
  });

  /// Stored ids, aligned with [sermons]: the id a row is removed by.
  final List<String> ids;
  final List<Sermon> sermons;
  final int missing;
  final void Function(String id) onRemove;
  final void Function(String id, Sermon sermon) onConfirmRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${messageCountLabel(sermons.length)} · newest first',
          style: KharisText.meta.copyWith(color: k.muted),
        ),
        if (missing > 0) ...[
          const SizedBox(height: KSpace.xs),
          Text(
            missing == 1
                ? '1 favourite is no longer in the library'
                : '$missing favourites are no longer in the library',
            style: KharisText.meta.copyWith(color: k.muted),
          ),
        ],
        const SizedBox(height: KSpace.x3),
        KButton(
          label: 'Play',
          icon: KIcons.play,
          expand: true,
          onPressed: sermons.isEmpty
              ? null
              : () =>
                    startPlayback(context, ref, sermons.first, queue: sermons),
        ),
        if (sermons.isNotEmpty) ...[
          const SizedBox(height: KSpace.x3),
          KListGroup(
            children: [
              for (final (index, sermon) in sermons.indexed)
                Dismissible(
                  key: ValueKey('favorite-${ids[index]}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => onRemove(ids[index]),
                  background: ColoredBox(
                    color: k.error,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpace.x3,
                        ),
                        child: Text(
                          'Remove',
                          style: KharisText.link.copyWith(color: k.onError),
                        ),
                      ),
                    ),
                  ),
                  child: CollectionMessageRow(
                    sermon: sermon,
                    removeLabel: 'Remove ${sermon.title} from Favourites',
                    onTap: () =>
                        startPlayback(context, ref, sermon, queue: sermons),
                    onRemove: () => onConfirmRemove(ids[index], sermon),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
