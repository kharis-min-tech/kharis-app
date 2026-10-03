import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// The member's Favorites: every message they hearted in the player, newest
/// favorited first, as a quick go-to separate from their playlists.
///
/// Tapping a row plays it with Favorites (in this order) as the queue. A row
/// leaves by swiping it away or from its ⋮ menu, with an Undo.
///
/// Reached as a pushed route (`/favorites`) from More and the top of
/// Playlists, so the AppBar back button always exits.
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
          content: const Text('Removed from Favorites'),
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

  void _showRowMenu(String id, Sermon sermon) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.kc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.heart_broken_outlined,
                color: sheetContext.kc.onBg,
              ),
              title: Text(
                'Remove from Favorites',
                style: AppTypography.ui(
                  size: 15,
                  weight: FontWeight.w600,
                  color: sheetContext.kc.onBg,
                ),
              ),
              subtitle: Text(
                sermon.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(
                  fontSize: 12,
                  color: sheetContext.kc.muted,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _remove(id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

    final Widget body;
    if ((favoritesAsync.isLoading && !favoritesAsync.hasValue) ||
        (resolution.pending > 0 && sermons.isEmpty)) {
      body = Center(
        child: CircularProgressIndicator(
          color: context.kc.accentInk,
          strokeWidth: 2,
        ),
      );
    } else if (favoritesAsync.hasError && !favoritesAsync.hasValue) {
      body = const _FavoritesMessage(
        icon: Icons.cloud_off_outlined,
        headline: "Your Favorites couldn't be loaded",
        body: 'Check your connection and try again.',
      );
    } else if (storedCount == 0) {
      body = const _FavoritesMessage(
        icon: Icons.favorite_border_rounded,
        headline: 'No favorites yet',
        body:
            'While a message plays, tap the heart beside its title to save '
            'it here. Favorites are your quick go-to, kept apart from your '
            'playlists.',
      );
    } else {
      body = _FavoritesList(
        ids: ids,
        sermons: sermons,
        missing: resolution.missing,
        onRemove: _remove,
        onMore: _showRowMenu,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.kc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Favorites',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.display(
            size: 26,
            weight: FontWeight.w700,
            color: context.kc.onBg,
          ),
        ),
      ),
      body: body,
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({
    required this.ids,
    required this.sermons,
    required this.missing,
    required this.onRemove,
    required this.onMore,
  });

  /// Stored ids, aligned with [sermons]: the id a row is removed by.
  final List<String> ids;
  final List<Sermon> sermons;
  final int missing;
  final void Function(String id) onRemove;
  final void Function(String id, Sermon sermon) onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSermon = ref.watch(currentSermonProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sermons.length == 1
                      ? '1 message · newest first'
                      : '${sermons.length} messages · newest first',
                  style: AppTypography.labelMd.copyWith(
                    fontSize: 12,
                    color: context.kc.muted,
                  ),
                ),
                if (missing > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    missing == 1
                        ? '1 favorite is no longer in the library'
                        : '$missing favorites are no longer in the library',
                    style: AppTypography.bodySm.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: context.kc.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: sermons.isEmpty
                        ? null
                        : () => startPlayback(
                            context,
                            ref,
                            sermons.first,
                            queue: sermons,
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.kc.accent,
                      foregroundColor: context.kc.onAccent,
                      disabledBackgroundColor: context.kc.accent.withValues(
                        alpha: 0.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(
                      'Play all',
                      style: AppTypography.ui(
                        size: 15,
                        weight: FontWeight.w700,
                        color: context.kc.onAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: context.kc.divider, height: 1),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final id = ids[index];
            final sermon = sermons[index];
            final isCurrent = currentSermon?.id == sermon.id;
            final isPlaying = isCurrent && (playerState?.playing ?? false);
            final dateLabel = sermon.publishedAt != null
                ? DateFormat('MMM yyyy').format(sermon.publishedAt!)
                : '';
            return Dismissible(
              key: ValueKey('favorite-$id'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onRemove(id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.md),
                color: AppColors.danger,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.heart_broken_rounded, color: Colors.white),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Remove',
                      style: AppTypography.ui(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              child: SermonListItem(
                title: sermon.title,
                speaker: sermon.speaker,
                category: sermon.series ?? sermon.category,
                durationLabel: sermon.formattedDuration,
                dateLabel: dateLabel,
                artworkColor: sermon.artworkColor,
                artworkUrl: sermon.artworkUrl,
                listIndex: index,
                isPlaying: isPlaying,
                onTap: () =>
                    startPlayback(context, ref, sermon, queue: sermons),
                onMoreTap: () => onMore(id, sermon),
              ),
            );
          }, childCount: sermons.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ── Empty / error state ───────────────────────────────────────────────────────

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({
    required this.icon,
    required this.headline,
    required this.body,
  });

  final IconData icon;
  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
          ],
        ),
      ),
    );
  }
}
