import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';

/// The pinned Favorites row at the top of Playlists: the quick go-to for
/// hearted messages. A full-width row with a gold heart, deliberately unlike
/// the playlist grid cards below it, since Favorites is not a playlist.
class FavoritesTile extends ConsumerWidget {
  const FavoritesTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(favoritesProvider).valueOrNull?.sermonIds.length ?? 0;
    final subtitle = switch (count) {
      0 => 'Tap the heart in the player to save a message here',
      1 => '1 message',
      _ => '$count messages',
    };

    return Semantics(
      button: true,
      label: 'Favourites, $subtitle',
      excludeSemantics: true,
      child: PressEffect(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: context.kc.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.kc.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.kc.accent,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: context.kc.onAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Favourites',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        size: 18,
                        weight: FontWeight.w700,
                        color: context.kc.onBg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 13,
                        color: context.kc.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: context.kc.muted),
            ],
          ),
        ),
      ),
    );
  }
}
