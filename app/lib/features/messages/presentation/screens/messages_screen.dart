import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/home/presentation/widgets/home_continue_listening.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/player/presentation/widgets/download_button.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../message_list.dart';
import 'downloads_screen.dart';

/// The landing page's tabs. Books shows only once a message carries a
/// passage.
enum MessagesTab {
  forYou('For you'),
  books('Books'),
  themes('Themes'),
  series('Series'),
  downloads('Downloads');

  const MessagesTab(this.label);

  final String label;
}

/// Recommendations shown under "Recommended for you".
const _recommendedCount = 5;

/// The newest series' latest message with its part number, or, when no
/// message is in a series, the newest message. Null for an empty library.
({Sermon sermon, int? part})? featuredMessage(List<Sermon> sermons) {
  if (sermons.isEmpty) return null;
  final newest = newestFirst(sermons);
  for (final s in newest) {
    final series = s.series;
    if (series == null || series.isEmpty) continue;
    final parts = seriesParts(sermons, series);
    return (sermon: s, part: parts.indexOf(s) + 1);
  }
  return (sermon: newest.first, part: null);
}

/// Up to [_recommendedCount] messages like [played]: the rest of its series
/// first (in order), then its theme, newest first. Never [played] itself or
/// anything in [exclude].
List<Sermon> recommendedFor(
  Sermon played,
  List<Sermon> sermons, {
  Set<String> exclude = const {},
}) {
  final skip = {played.id, ...exclude};
  final out = <Sermon>[];
  final series = played.series;
  if (series != null && series.isNotEmpty) {
    out.addAll(seriesParts(sermons, series).where((s) => skip.add(s.id)));
  }
  final topic = sermonTopic(played);
  out.addAll(
    newestFirst(
      sermons.where((s) => sermonTopic(s) == topic),
    ).where((s) => skip.add(s.id)),
  );
  return out.take(_recommendedCount).toList();
}

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  MessagesTab _tab = MessagesTab.forYou;

  @override
  Widget build(BuildContext context) {
    final hasBooks = ref.watch(
      messageBooksProvider.select((b) => b.isNotEmpty),
    );
    final tabs = [
      for (final t in MessagesTab.values)
        if (t != MessagesTab.books || hasBooks) t,
    ];
    final tab = tabs.contains(_tab) ? _tab : MessagesTab.forYou;
    final library = ref.watch(sermonLibraryProvider);
    final bottom =
        KSize.contentBottomPad + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: ref.read(sermonLibraryProvider.notifier).refresh,
          child: CustomScrollView(
            key: const PageStorageKey('messages-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: KScreenHeader(
                  title: 'Messages',
                  actions: [
                    KIconButton(
                      key: const Key('messages-search'),
                      icon: KIcons.search,
                      label: 'Search messages',
                      onPressed: () => context.push('/messages/search'),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: KTabs(
                  key: const Key('messages-tabs'),
                  tabs: [for (final t in tabs) t.label],
                  currentIndex: tabs.indexOf(tab),
                  onChanged: (i) => setState(() => _tab = tabs[i]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: KSpace.section)),
              if (library.sermons.isEmpty &&
                  !library.loaded &&
                  tab != MessagesTab.downloads)
                const _Skeleton()
              else if (library.sermons.isEmpty &&
                  library.offline &&
                  tab != MessagesTab.downloads)
                SliverToBoxAdapter(
                  child: KErrorState(
                    message:
                        'Couldn\u2019t load messages. Check your '
                        'connection and try again.',
                    onRetry: ref.read(sermonLibraryProvider.notifier).refresh,
                  ),
                )
              else
                ...switch (tab) {
                  MessagesTab.forYou => [
                    _ForYou(
                      onDownloads: () =>
                          setState(() => _tab = MessagesTab.downloads),
                    ),
                  ],
                  MessagesTab.books => const [_Books()],
                  MessagesTab.themes => const [_Themes()],
                  MessagesTab.series => const [_Series()],
                  MessagesTab.downloads => const [DownloadsList()],
                },
              if (library.hydrationFailed && tab != MessagesTab.downloads)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: KSpace.section),
                    child: KErrorState(
                      key: const Key('messages-hydration-failed'),
                      message: 'Some older messages haven\u2019t loaded.',
                      onRetry: ref
                          .read(sermonLibraryProvider.notifier)
                          .retryHydration,
                    ),
                  ),
                ),
              SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      sliver: SliverList.list(
        children: [
          const KSkeleton(height: KSize.hero, radius: KRadius.card),
          for (var i = 0; i < 4; i++) ...[
            const SizedBox(height: KSpace.lg),
            const KSkeleton(height: KSize.listRow),
          ],
        ],
      ),
    );
  }
}

/// Wraps [children] as gutter-padded box slivers stacked with section gaps.
class _Sections extends StatelessWidget {
  const _Sections(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      sliver: SliverList.list(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: KSpace.section),
            child,
          ],
        ],
      ),
    );
  }
}

class _ForYou extends ConsumerWidget {
  const _ForYou({required this.onDownloads});

  /// Opens the Downloads tab, from the empty state.
  final VoidCallback onDownloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(sermonLibraryProvider);
    final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
    final featured = featuredMessage(sermons);
    final recent = ref.watch(recentlyPlayedProvider);
    final lastPlayed = recent.isEmpty ? null : recent.first;
    final recommended = lastPlayed == null
        ? const <Sermon>[]
        : recommendedFor(
            lastPlayed,
            sermons,
            exclude: {for (final s in recent) s.id},
          );

    return _Sections([
      // Only once the archive has finished loading, and came back empty.
      if (library.loaded && library.sermons.isEmpty)
        KEmptyState(
          key: const Key('messages-empty'),
          icon: KIcons.soundwave,
          title: 'No messages yet',
          hint: 'New messages show here as soon as they are online.',
          action: KButton(
            label: 'Your downloads',
            variant: KButtonVariant.outline,
            onPressed: onDownloads,
          ),
        ),
      if (featured != null) _Hero(featured.sermon, part: featured.part),
      const HomeContinueListening(),
      if (lastPlayed != null && recommended.isNotEmpty)
        Column(
          key: const Key('messages-recommended'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KSectionHeader(title: 'Recommended for you'),
            Text(
              'Because you listened to ${lastPlayed.title}',
              style: KharisText.meta.copyWith(color: context.k.muted),
            ),
            const SizedBox(height: KSpace.lg),
            KListGroup(
              children: [
                for (final s in recommended)
                  MessageRow(
                    key: ValueKey(s.id),
                    sermon: s,
                    queue: recommended,
                  ),
              ],
            ),
          ],
        ),
      const _Collections(),
    ]);
  }
}

class _Hero extends ConsumerWidget {
  const _Hero(this.sermon, {this.part});

  final Sermon sermon;
  final int? part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = sermon.hasAudio
        ? ref.watch(downloadStatusProvider(sermon.id))
        : null;
    final repository = ref.read(downloadsRepositoryProvider);
    ref.listen<DownloadStatus>(downloadStatusProvider(sermon.id), (_, next) {
      if (next is! DownloadFailed) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(DownloadButton.failureMessage(next.reason))),
      );
      repository.clearFailure(sermon.id);
    });
    final meta = [
      if (sermon.speaker.trim().isNotEmpty) sermon.speaker.trim(),
      ?messageLength(sermon.duration),
    ].join(' \u00b7 ');

    return KMessageHero(
      key: const Key('messages-hero'),
      title: sermon.title,
      badge: part == null ? null : 'New \u00b7 Part $part',
      meta: meta.isEmpty ? null : meta,
      image: messageArtwork(sermon, size: 3 * 390),
      listenKey: const Key('messages-hero-listen'),
      onListen: () => unawaited(startPlayback(context, ref, sermon)),
      downloadKey: const Key('messages-hero-download'),
      onDownload: switch (status) {
        null => null,
        Downloading() => () => repository.cancel(sermon.id),
        Downloaded() => () => context.push('/downloads'),
        _ => () => unawaited(repository.download(sermon)),
      },
      downloadState: switch (status) {
        Downloading() => KMessageDownloadState.downloading,
        Downloaded() => KMessageDownloadState.done,
        _ => KMessageDownloadState.idle,
      },
      downloadProgress: status is Downloading ? status.fraction : null,
      downloadLabel: switch (status) {
        Downloading() => 'Cancel download',
        Downloaded() => 'Downloaded',
        _ => 'Download',
      },
      addToCollectionKey: const Key('messages-hero-collect'),
      onAddToCollection: () => unawaited(
        showAddToPlaylistSheet(
          context,
          sermonId: sermon.id,
          sermonTitle: sermon.title,
        ),
      ),
    );
  }
}

class _Collections extends ConsumerWidget {
  const _Collections();

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(playlistRepositoryProvider);
    if (!repo.hasUser) {
      ref.read(anonymousSignInProvider).ensure();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still signing you in. Try again in a moment.'),
        ),
      );
      return;
    }
    final name = await showPlaylistNameDialog(context, title: 'New collection');
    if (name == null || !context.mounted) return;
    final id = repo.create(name);
    unawaited(context.push('/playlists/$id'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).valueOrNull;
    if (playlists == null) return const SizedBox.shrink();

    return Column(
      key: const Key('messages-collections'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KSectionHeader(
          title: 'Your collections',
          actionLabel: '+ New',
          onAction: () => unawaited(_create(context, ref)),
        ),
        if (playlists.isEmpty)
          Text(
            'Group messages you want to come back to.',
            style: KharisText.meta.copyWith(color: context.k.muted),
          )
        else
          KListGroup(
            children: [
              for (final p in playlists)
                KListRow(
                  key: ValueKey('collection-${p.id}'),
                  title: p.name,
                  meta: p.sermonIds.length == 1
                      ? '1 message'
                      : '${p.sermonIds.length} messages',
                  leading: const KIconTile(KIcons.collection),
                  showChevron: true,
                  onTap: () => context.push('/playlists/${p.id}'),
                ),
            ],
          ),
      ],
    );
  }
}

/// A list of named groups (books, themes, series), each opening its
/// messages.
class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.listKey,
    this.artwork = false,
  });

  final List<({String name, List<Sermon> sermons})> groups;

  /// Leads each row with its newest message's artwork.
  final bool artwork;
  final Key listKey;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      sliver: KSliverListGroup(
        key: listKey,
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          final count = g.sermons.length == 1
              ? '1 message'
              : '${g.sermons.length} messages';
          return KListRow(
            key: ValueKey('group-${g.name}'),
            title: g.name,
            meta: count,
            leading: artwork
                ? KThumbnail(image: messageArtwork(g.sermons.last))
                : null,
            showChevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    MessageListScreen(title: g.name, sermons: g.sermons),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Books extends ConsumerWidget {
  const _Books();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(messageBooksProvider);
    return _GroupList(
      listKey: const Key('messages-books'),
      groups: [for (final b in books) (name: b.name, sermons: b.sermons)],
    );
  }
}

class _Themes extends ConsumerWidget {
  const _Themes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
    final labels = ref.watch(categoryLabelsProvider);
    final byTopic = <String, List<Sermon>>{};
    for (final s in sermons) {
      (byTopic[sermonTopic(s)] ??= []).add(s);
    }
    return _GroupList(
      listKey: const Key('messages-themes'),
      groups: [
        for (final label in labels)
          if (byTopic[label] case final list?)
            (name: label, sermons: newestFirst(list)),
      ],
    );
  }
}

class _Series extends ConsumerWidget {
  const _Series();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
    final series = ref.watch(seriesListProvider);
    return _GroupList(
      listKey: const Key('messages-series'),
      groups: [
        for (final s in series)
          (name: s.name, sermons: seriesParts(sermons, s.name)),
      ],
      artwork: true,
    );
  }
}
