import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/providers/content_config_providers.dart';
import 'package:kharis_app/features/messages/data/curation_repository.dart'
    show FeaturedMode;

/// Messages tab curation in the Content Studio: how the featured carousel is
/// filled (`config/featured`), or whether there is one at all.

void _snack(
  ScaffoldMessengerState messenger,
  String text, {
  bool error = false,
}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error
          ? AppColors.errorContainer
          : AppColors.surfaceElevated,
    ),
  );
}

class _CurationCard extends StatelessWidget {
  const _CurationCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.heading,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

Widget _muted(String text) => Padding(
  padding: const EdgeInsets.only(top: AppSpacing.xs),
  child: Text(
    text,
    style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
  ),
);

// ── Featured mode ─────────────────────────────────────────────────────────────

/// Auto (the newest uploads), Pinned (the starred sermons below) or Off (no
/// carousel; Messages leads with its latest messages).
class FeaturedModeCard extends ConsumerWidget {
  const FeaturedModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(adminFeaturedModeProvider);
    final mode = modeAsync.valueOrNull;

    return _CurationCard(
      title: 'Featured',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<FeaturedMode>(
            segments: const [
              ButtonSegment(
                value: FeaturedMode.auto,
                label: Text('Auto (latest)'),
              ),
              ButtonSegment(value: FeaturedMode.pinned, label: Text('Pinned')),
              ButtonSegment(value: FeaturedMode.off, label: Text('Off')),
            ],
            selected: {mode ?? FeaturedMode.auto},
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.secondary
                    : AppColors.surfaceSubtle,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.onSecondary
                    : AppColors.onSurfaceVariant,
              ),
            ),
            onSelectionChanged: mode == null
                ? null
                : (selection) => _setMode(context, ref, selection.first),
          ),
        ),
        if (modeAsync.hasError)
          _muted('Could not load the featured setting.')
        else if (mode == FeaturedMode.auto)
          _muted('Stars only apply in Pinned mode.')
        else if (mode == FeaturedMode.off)
          _muted(
            'No featured carousel: Messages leads with the latest messages.',
          ),
      ],
    );
  }

  Future<void> _setMode(
    BuildContext context,
    WidgetRef ref,
    FeaturedMode mode,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(contentConfigRepositoryProvider).setFeaturedMode(mode);
      _snack(messenger, switch (mode) {
        FeaturedMode.auto => 'Featured now shows the latest uploads.',
        FeaturedMode.pinned => 'Featured now shows your starred sermons.',
        FeaturedMode.off =>
          'Featured is off. Messages leads with the latest messages.',
      });
    } catch (e) {
      _snack(messenger, 'Could not change Featured: $e', error: true);
    }
  }
}
