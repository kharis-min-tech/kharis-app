import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';

/// Home's Giving shortcut: names the member's campus and switches to the
/// Giving tab, which shows where the gift goes.
class GivingShortcutCard extends ConsumerWidget {
  const GivingShortcutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campus =
        ref.watch(currentBranchProvider).valueOrNull ?? kChurchWideRecipient;
    final kc = context.kc;
    return Semantics(
      button: true,
      label: 'Give to $campus',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: AppShadows.card,
        ),
        child: Material(
          key: const Key('home-giving'),
          color: kc.surface,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // Giving is a tab: switch to it rather than stacking it.
            onTap: () => context.go('/giving'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kc.chipBg,
                      borderRadius: AppRadius.tileBorder,
                    ),
                    child: Icon(
                      Icons.volunteer_activism_outlined,
                      size: 20,
                      color: kc.onChip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Give',
                          style: AppTypography.ui(
                            size: 15,
                            weight: FontWeight.w700,
                          ).copyWith(color: kc.onBg, height: 1.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          campus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 13,
                          ).copyWith(color: kc.muted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kc.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
