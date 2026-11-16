import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Home's way into giving: who the gift goes to, 2 Corinthians 9:7, and the
/// one Give button, which opens the Give screen.
class HomeGiveCard extends ConsumerWidget {
  const HomeGiveCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final branch = ref.watch(homeBranchProvider).valueOrNull;

    return KCard(
      key: const Key('home-give'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Give',
              style: KharisText.section.copyWith(color: k.text),
            ),
          ),
          if (branch != null) ...[
            const SizedBox(height: KSpace.xxs),
            Text(
              'To $branch',
              style: KharisText.meta.copyWith(color: k.muted),
            ),
          ],
          const SizedBox(height: KSpace.lg),
          Text.rich(
            TextSpan(
              style: KharisText.meta.copyWith(color: k.muted),
              children: [
                const TextSpan(
                  text: '\u201cGod loveth a cheerful giver.\u201d ',
                ),
                TextSpan(
                  text: '2 Corinthians 9:7',
                  style: KharisText.itemTitle.copyWith(color: k.highlightText),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.xxl),
          KButton(
            key: const Key('home-give-button'),
            label: 'Give',
            size: KButtonSize.cta,
            expand: true,
            onPressed: () => context.push('/give'),
          ),
        ],
      ),
    );
  }
}
