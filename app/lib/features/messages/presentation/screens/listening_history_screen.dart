import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/shared/providers/listening_history_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../message_list.dart';

/// `/history`: every message the member has started, the most recent first,
/// each with how far they got; tapping resumes it.
class ListeningHistoryScreen extends ConsumerWidget {
  const ListeningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plays = ref.watch(listeningHistoryProvider);
    final queue = [for (final p in plays) p.sermon];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: KScreenHeader(title: 'History')),
            const SliverToBoxAdapter(child: SizedBox(height: KSpace.lg)),
            if (plays.isEmpty)
              const SliverToBoxAdapter(
                child: KEmptyState(
                  key: Key('history-empty'),
                  icon: KIcons.soundwave,
                  title: 'Nothing played yet',
                  hint: 'Messages you listen to show here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
                sliver: KSliverListGroup(
                  key: const Key('history-list'),
                  itemCount: plays.length,
                  itemBuilder: (context, i) => MessageRow(
                    key: ValueKey('history-${plays[i].sermon.id}'),
                    sermon: plays[i].sermon,
                    queue: queue,
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom:
                    KSize.contentBottomPad +
                    MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
