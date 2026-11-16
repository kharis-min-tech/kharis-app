import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

String _days(int count) => count == 1 ? '1 day' : '$count days';

/// The card overlapping the hero: today's reading with whether it has been
/// read, then the reading and messages streaks. Without a reading today
/// (or with [showReading] off, the Studio's switch) the first cell opens
/// the Bible instead.
class HomeStatsStrip extends ConsumerWidget {
  const HomeStatsStrip({super.key, this.showReading = true});

  final bool showReading;

  KStat _readingCell(BuildContext context, WidgetRef ref) {
    final bible = KStat(
      key: const Key('home-stat-bible'),
      label: 'Read',
      value: 'Bible',
      semanticLabel: 'Open the Bible',
      onTap: () => context.go('/bible'),
    );
    if (!showReading) return bible;

    final content = ref.watch(dailyContentProvider);
    final reading = content.valueOrNull?.reading;
    if (reading == null) {
      if (content.hasValue || content.hasError) return bible;
      return const KStat(
        key: Key('home-stat-reading-loading'),
        label: 'Today\u2019s reading',
        value: '',
        semanticLabel: 'Loading today\u2019s reading',
        loading: true,
      );
    }

    final version = ref.watch(selectedBibleProvider);
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    final reference = reading.reference.trim();
    final chapters = {
      for (final at in parseReadingReferences(reference, index))
        index.label(at.wholeChapter),
    };
    // Nothing parsed: the Studio's own wording.
    final title = chapters.isNotEmpty
        ? chapters.join(' \u00b7 ')
        : (reference.isEmpty ? reading.title : reference);
    final read = ref.watch(readTodayProvider);
    final status = read ? 'Read' : 'Not read';

    return KStat(
      key: const Key('home-stat-reading'),
      label: 'Today\u2019s reading',
      value: title,
      status: status,
      statusDone: read,
      semanticLabel: 'Today\u2019s reading: $title. $status. Open',
      onTap: () => context.push('/reading'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streaks = ref.watch(streaksProvider);

    return KStatsStrip(
      stats: [
        _readingCell(context, ref),
        KStat(
          key: const Key('home-stat-reading-streak'),
          label: 'Reading',
          value: '${streaks.readingStreak}',
          icon: KIcons.flame,
          caption: 'day streak',
          semanticLabel: 'Reading streak, ${_days(streaks.readingStreak)}',
          onTap: () => context.go('/bible'),
        ),
        KStat(
          key: const Key('home-stat-messages-streak'),
          label: 'Messages',
          value: '${streaks.messagesStreak}',
          icon: KIcons.messages,
          caption: 'day streak',
          semanticLabel: 'Messages streak, ${_days(streaks.messagesStreak)}',
          onTap: () => context.go('/messages'),
        ),
      ],
    );
  }
}
