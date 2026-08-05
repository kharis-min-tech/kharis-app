import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// Bottom sheet that files a message into the member's playlists.
///
/// Rows toggle membership live (check = already in that playlist), so a
/// message can be added to several playlists in one visit. "New playlist"
/// creates one and files the message in it immediately.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required String sermonId,
  required String sermonTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) =>
        AddToPlaylistSheet(sermonId: sermonId, sermonTitle: sermonTitle),
  );
}

class AddToPlaylistSheet extends ConsumerWidget {
  const AddToPlaylistSheet({
    super.key,
    required this.sermonId,
    required this.sermonTitle,
  });

  final String sermonId;
  final String sermonTitle;

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(playlistRepositoryProvider);
    final name = await showPlaylistNameDialog(context, title: 'New playlist');
    if (name == null || !repo.hasUser) return;
    final playlistId = repo.create(name);
    repo.addSermon(playlistId, sermonId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playlistRepositoryProvider);
    if (!repo.hasUser) {
      // Kick another anonymous sign-in attempt so "try again in a moment"
      // stays honest even when the launch-time attempt failed (offline first
      // run) — closing and reopening this sheet retries. Single-flight, so
      // rebuilds never stack sign-in calls.
      ref.read(anonymousSignInProvider).ensure();
    }
    final playlistsAsync = ref.watch(playlistsProvider);
    final playlists = playlistsAsync.valueOrNull ?? const <Playlist>[];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.kc.outline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add to playlist',
                    style: AppTypography.display(
                      size: 18,
                      weight: FontWeight.w700,
                      color: context.kc.onBg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sermonTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      fontSize: 13,
                      color: context.kc.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (!repo.hasUser)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Text(
                  'Hold on — we’re still signing you in. '
                  'Try again in a moment.',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 13,
                    color: context.kc.muted,
                  ),
                ),
              )
            else ...[
              ListTile(
                onTap: () => _createAndAdd(context, ref),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.kc.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: context.kc.accentInk,
                    size: 24,
                  ),
                ),
                title: Text(
                  'New playlist',
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: context.kc.accentInk,
                  ),
                ),
              ),
              if (playlistsAsync.isLoading && playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.kc.accentInk,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      final isIn = playlist.contains(sermonId);
                      return ListTile(
                        onTap: () {
                          if (isIn) {
                            repo.removeSermon(playlist.id, sermonId);
                          } else {
                            repo.addSermon(playlist.id, sermonId);
                          }
                        },
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: ArtworkImage(
                            url: null,
                            gradientIndex: playlistGradientIndex(playlist.id),
                            radius: AppRadius.md,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 15,
                            weight: FontWeight.w600,
                            color: context.kc.onBg,
                          ),
                        ),
                        subtitle: Text(
                          playlist.sermonIds.length == 1
                              ? '1 message'
                              : '${playlist.sermonIds.length} messages',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 11.5,
                            color: context.kc.muted,
                          ),
                        ),
                        trailing: Icon(
                          isIn
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          color: isIn ? context.kc.accentInk : context.kc.muted,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
