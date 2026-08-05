import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

enum _PlaylistAction { rename, delete }

/// One playlist: its messages resolved against the loaded catalogue, with
/// rename / delete / remove-message management.
///
/// Reached only as a pushed route (`/playlists/:id`), so the AppBar back
/// button pops to the playlists home — never trapping the member.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Rename playlist',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.kc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Delete playlist?',
          style: AppTypography.display(
            size: 20,
            weight: FontWeight.w700,
            color: dialogContext.kc.onBg,
          ),
        ),
        content: Text(
          '"${playlist.name}" will be removed from your library. '
          'The messages themselves are untouched.',
          style: AppTypography.bodySm.copyWith(
            fontSize: 14,
            height: 1.5,
            color: dialogContext.kc.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w600,
                color: dialogContext.kc.muted,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(
              'Delete',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(playlistRepositoryProvider).deletePlaylist(playlist.id);
    Navigator.of(context).maybePop();
  }

  void _removeSermon(BuildContext context, WidgetRef ref, Sermon sermon) {
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
                Icons.playlist_remove_rounded,
                color: sheetContext.kc.onBg,
              ),
              title: Text(
                'Remove from this playlist',
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
                ref
                    .read(playlistRepositoryProvider)
                    .removeSermon(playlistId, sermon.id);
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(playlistByIdProvider(playlistId));
    final playlistsAsync = ref.watch(playlistsProvider);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.kc.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: Center(
          child: playlistsAsync.isLoading
              ? CircularProgressIndicator(
                  color: context.kc.accentInk,
                  strokeWidth: 2,
                )
              : Text(
                  'This playlist no longer exists.',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 14,
                    color: context.kc.muted,
                  ),
                ),
        ),
      );
    }

    final sermonsAsync = ref.watch(sermonsProvider);
    final sermons = ref.watch(playlistSermonsProvider(playlistId));
    final missing = playlist.sermonIds.length - sermons.length;
    final currentSermon = ref.watch(currentSermonProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.kc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Playlist',
          style: AppTypography.ui(
            size: 14,
            weight: FontWeight.w600,
            color: context.kc.muted,
          ),
        ),
        actions: [
          PopupMenuButton<_PlaylistAction>(
            icon: Icon(Icons.more_vert_rounded, color: context.kc.onBg),
            color: context.kc.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onSelected: (action) => switch (action) {
              _PlaylistAction.rename => _rename(context, ref, playlist),
              _PlaylistAction.delete => _confirmDelete(context, ref, playlist),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _PlaylistAction.rename,
                child: Text(
                  'Rename',
                  style: AppTypography.ui(size: 14, color: context.kc.onBg),
                ),
              ),
              PopupMenuItem(
                value: _PlaylistAction.delete,
                child: Text(
                  'Delete playlist',
                  style: AppTypography.ui(size: 14, color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Artwork + meta ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          boxShadow: AppShadows.miniPlayer,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PlaylistArt(playlist: playlist),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    playlist.name,
                    style: AppTypography.display(
                      size: 26,
                      weight: FontWeight.w700,
                      color: context.kc.onBg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sermons.length == 1
                        ? '1 message'
                        : '${sermons.length} messages',
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 12,
                      color: context.kc.muted,
                    ),
                  ),
                  if (missing > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      missing == 1
                          ? '1 saved message is no longer in the library'
                          : '$missing saved messages are no longer in '
                                'the library',
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
                          : () => startPlayback(ref, sermons.first),
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

          // ── Loading catalogue ─────────────────────────────────────────────
          if (sermonsAsync.isLoading && sermons.isEmpty)
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
            )
          // ── Empty playlist invitation ─────────────────────────────────────
          else if (sermons.isEmpty && playlist.sermonIds.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                child: Column(
                  children: [
                    Icon(
                      Icons.library_music_outlined,
                      size: 44,
                      color: context.kc.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nothing here yet. On the Messages tab, tap the ⋮ '
                      'menu on any message to add it to this playlist.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 13,
                        height: 1.5,
                        color: context.kc.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Ordered sermon list (Messages row spec) ───────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final sermon = sermons[index];
              final isCurrent = currentSermon?.id == sermon.id;
              final isPlaying = isCurrent && (playerState?.playing ?? false);
              final dateLabel = sermon.publishedAt != null
                  ? DateFormat('MMM yyyy').format(sermon.publishedAt!)
                  : '';
              return SermonListItem(
                key: ValueKey(sermon.id),
                title: sermon.title,
                speaker: sermon.speaker,
                category: sermon.series ?? sermon.category,
                durationLabel: sermon.formattedDuration,
                dateLabel: dateLabel,
                artworkColor: sermon.artworkColor,
                artworkUrl: sermon.artworkUrl,
                listIndex: index,
                isPlaying: isPlaying,
                onTap: () => startPlayback(ref, sermon),
                onMoreTap: () => _removeSermon(context, ref, sermon),
              );
            }, childCount: sermons.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
