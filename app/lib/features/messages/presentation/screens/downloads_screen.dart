import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../message_list.dart';

/// "820 KB", "48 MB", "1.2 GB".
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).round()} MB';
  return '${(bytes / kb).ceil()} KB';
}

/// The saved messages as slivers: a total line and a row for each, newest
/// saved first, each removable by a swipe or its remove button. Shows an
/// empty state when nothing is saved.
class DownloadsList extends ConsumerWidget {
  const DownloadsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final repository = ref.read(downloadsRepositoryProvider);

    if (downloads.isEmpty) {
      return SliverToBoxAdapter(
        child: KEmptyState(
          key: const Key('downloads-empty'),
          icon: KIcons.download,
          title: 'No downloads yet',
          hint: 'Download a message to listen without a connection.',
          action: KButton(
            label: 'Browse messages',
            variant: KButtonVariant.outline,
            onPressed: () => context.go('/messages'),
          ),
        ),
      );
    }

    final total = downloads.fold<int>(0, (sum, d) => sum + d.bytes);
    final queue = [for (final d in downloads) d.sermon];
    final count = downloads.length == 1
        ? '1 message'
        : '${downloads.length} messages';

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: KSpace.lg),
              child: Text(
                '$count \u00b7 ${formatBytes(total)} on this phone',
                key: const Key('downloads-total'),
                style: KharisText.meta.copyWith(color: context.k.muted),
              ),
            ),
          ),
          KSliverListGroup(
            itemCount: downloads.length,
            itemBuilder: (context, i) {
              final d = downloads[i];
              void remove() => unawaited(repository.delete(d.sermon.id));
              return Dismissible(
                key: ValueKey('download-${d.sermon.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => remove(),
                child: MessageRow(
                  sermon: d.sermon,
                  queue: queue,
                  trailingLabel: formatBytes(d.bytes),
                  trailing: KIconButton(
                    key: ValueKey('download-remove-${d.sermon.id}'),
                    icon: KIcons.close,
                    label: 'Remove download',
                    onPressed: remove,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// `/downloads`: every saved message.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: KScreenHeader(title: 'Downloads')),
            const SliverToBoxAdapter(child: SizedBox(height: KSpace.lg)),
            const DownloadsList(),
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
