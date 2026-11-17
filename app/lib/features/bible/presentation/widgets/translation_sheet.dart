import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The translation switcher: a short sheet listing the approved translations
/// the account returns, the reading one marked. One tap switches (and
/// remembers) the translation and closes the sheet.
Future<void> showTranslationSheet(BuildContext context) =>
    showKBottomSheet<void>(
      context: context,
      title: 'Translation',
      builder: (_) => const TranslationSheet(),
    );

class TranslationSheet extends ConsumerWidget {
  const TranslationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBibleProvider);

    return ref
        .watch(biblesProvider)
        .when(
          loading: () => const Column(
            key: Key('bible-versions-loading'),
            mainAxisSize: MainAxisSize.min,
            children: [
              KSkeleton(height: KSize.listRow, radius: KRadius.card),
              SizedBox(height: KSpace.md),
              KSkeleton(height: KSize.listRow, radius: KRadius.card),
            ],
          ),
          error: (_, _) => KErrorState(
            message:
                'The translations didn\u2019t load. '
                'Check your connection and retry.',
            onRetry: () => ref.invalidate(biblesProvider),
          ),
          // Scrolls only when large text makes the list taller than the
          // screen.
          data: (bibles) => SingleChildScrollView(
            child: KListGroup(
              children: [
                for (final b in bibles)
                  _Translation(
                    key: Key('bible-version-${b.id}'),
                    bible: b,
                    selected: b.id == selected.id,
                    onTap: () => _choose(context, ref, b),
                  ),
              ],
            ),
          ),
        );
  }

  void _choose(BuildContext context, WidgetRef ref, BibleVersion bible) {
    unawaited(ref.read(selectedBibleProvider.notifier).select(bible));
    Navigator.of(context).pop();
  }
}

/// One translation: its abbreviation, its full name and a radio mark.
class _Translation extends StatelessWidget {
  const _Translation({
    super.key,
    required this.bible,
    required this.selected,
    required this.onTap,
  });

  final BibleVersion bible;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: KListRow(
        title: bible.abbreviation,
        meta: bible.title.isEmpty ? null : bible.title,
        trailing: KRadioMark(selected: selected),
        onTap: onTap,
      ),
    );
  }
}
