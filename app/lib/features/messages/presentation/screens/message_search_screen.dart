import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../message_list.dart';

/// How results are ordered; a single choice in the Sort sheet.
enum SearchSort {
  relevant('Most relevant'),
  newest('Newest first'),
  oldest('Oldest first'),
  shortest('Shortest first');

  const SearchSort(this.label);

  final String label;
}

/// A message's length band in the Length sheet.
enum LengthBand {
  under20('Under 20 min'),
  from20to40('20\u201340 min'),
  over40('Over 40 min');

  const LengthBand(this.label);

  final String label;

  /// The band [duration] falls in; null when the length is unknown.
  static LengthBand? of(Duration? duration) {
    if (duration == null || duration <= Duration.zero) return null;
    if (duration < const Duration(minutes: 20)) return under20;
    if (duration <= const Duration(minutes: 40)) return from20to40;
    return over40;
  }
}

/// What the search can be narrowed by, in chip order after Sort. Each opens
/// a [KFilterSheet].
enum SearchFilter {
  book('Book'),
  theme('Theme'),
  series('Series'),
  date('Date'),
  length('Length');

  const SearchFilter(this.label);

  final String label;
}

/// The member's narrowing choices; an empty set lets everything through.
typedef SearchFilters = Map<SearchFilter, Set<String>>;

/// Whether [sermon] passes every filter in [filters]. A message with no
/// known length fails only an active Length filter.
bool matchesFilters(Sermon sermon, SearchFilters filters, BibleIndex canon) {
  for (final MapEntry(key: filter, value: chosen) in filters.entries) {
    if (chosen.isEmpty) continue;
    final ok = switch (filter) {
      SearchFilter.book => messageBooks(sermon, canon).any(chosen.contains),
      SearchFilter.theme => chosen.contains(sermonTopic(sermon)),
      SearchFilter.series => chosen.contains(sermon.series ?? ''),
      SearchFilter.date => chosen.contains('${sermon.publishedAt?.year}'),
      SearchFilter.length => chosen.contains(
        LengthBand.of(sermon.duration)?.name,
      ),
    };
    if (!ok) return false;
  }
  return true;
}

/// [results] in [sort] order; Most relevant keeps the order given.
List<Sermon> sortResults(List<Sermon> results, SearchSort sort) {
  int date(Sermon a, Sermon b) =>
      (a.publishedAt ?? DateTime(0)).compareTo(b.publishedAt ?? DateTime(0));
  Duration length(Sermon s) =>
      s.duration == null || s.duration! <= Duration.zero
      ? const Duration(days: 1)
      : s.duration!;
  return switch (sort) {
    SearchSort.relevant => results,
    SearchSort.newest => [...results]..sort((a, b) => date(b, a)),
    SearchSort.oldest => [...results]..sort(date),
    SearchSort.shortest => [
      ...results,
    ]..sort((a, b) => length(a).compareTo(length(b))),
  };
}

/// `/messages/search`: type to search the whole archive (titles, speakers,
/// passages), sorted and narrowed by book, theme, series, date and length.
/// The empty field lists recent searches; filters alone list the matching
/// library.
class MessageSearchScreen extends ConsumerStatefulWidget {
  const MessageSearchScreen({super.key});

  @override
  ConsumerState<MessageSearchScreen> createState() =>
      _MessageSearchScreenState();
}

class _MessageSearchScreenState extends ConsumerState<MessageSearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(sermonSearchProvider),
  );
  final SearchFilters _filters = {};
  SearchSort _sort = SearchSort.relevant;
  final _canon = BibleIndex.bundled();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    ref.read(sermonSearchProvider.notifier).state = query;
  }

  void _remember() =>
      ref.read(recentSearchesProvider.notifier).add(_controller.text);

  List<KFilterOption<String>> _options(SearchFilter filter) {
    String n(int count) => count == 1 ? '1 message' : '$count messages';
    return switch (filter) {
      SearchFilter.book => [
        for (final b in ref.read(messageBooksProvider))
          KFilterOption(
            value: b.usfm,
            label: b.name,
            meta: n(b.sermons.length),
          ),
      ],
      SearchFilter.theme => [
        for (final t in ref.read(categoryLabelsProvider))
          if (t != 'All')
            KFilterOption(
              value: t,
              label: t,
              meta: n(ref.read(categoryCountsProvider)[t] ?? 0),
            ),
      ],
      SearchFilter.series => [
        for (final s in ref.read(seriesListProvider))
          KFilterOption(value: s.name, label: s.name, meta: n(s.count)),
      ],
      SearchFilter.date => [
        for (final y in ref.read(archiveYearsProvider))
          KFilterOption(
            value: '$y',
            label: '$y',
            meta: n(ref.read(archiveYearCountsProvider)[y] ?? 0),
          ),
      ],
      SearchFilter.length => [
        for (final b in LengthBand.values)
          KFilterOption(value: b.name, label: b.label),
      ],
    };
  }

  Future<void> _openSort() async {
    final chosen = await showKFilterSheet<SearchSort>(
      context: context,
      title: 'Sort',
      single: true,
      options: [
        for (final s in SearchSort.values)
          KFilterOption(value: s, label: s.label),
      ],
      selected: {_sort},
    );
    if (chosen == null || !mounted) return;
    setState(() => _sort = chosen.firstOrNull ?? SearchSort.relevant);
  }

  Future<void> _openFilter(SearchFilter filter) async {
    final chosen = await showKFilterSheet<String>(
      context: context,
      title: filter.label,
      options: _options(filter),
      selected: _filters[filter] ?? const {},
    );
    if (chosen == null || !mounted) return;
    setState(() => _filters[filter] = chosen);
  }

  String _chipLabel(SearchFilter filter) {
    final chosen = _filters[filter] ?? const {};
    if (chosen.isEmpty) return filter.label;
    if (chosen.length > 1) return '${filter.label} \u00b7 ${chosen.length}';
    final only = chosen.first;
    return switch (filter) {
      SearchFilter.book =>
        ref
                .read(messageBooksProvider)
                .where((b) => b.usfm == only)
                .firstOrNull
                ?.name ??
            only,
      SearchFilter.length => LengthBand.values.byName(only).label,
      _ => only,
    };
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(sermonSearchProvider).trim();
    final hasBooks = ref.watch(
      messageBooksProvider.select((b) => b.isNotEmpty),
    );
    final filtering = _filters.values.any((s) => s.isNotEmpty);
    final source = query.isNotEmpty
        ? ref.watch(searchResultsProvider)
        : filtering
        ? newestFirst(ref.watch(sermonsProvider).valueOrNull ?? const [])
        : const <Sermon>[];
    final results = sortResults([
      for (final s in source)
        if (matchesFilters(s, _filters, _canon)) s,
    ], _sort);
    final loading = query.isNotEmpty && ref.watch(searchLoadingProvider);
    final recent = ref.watch(recentSearchesProvider);
    final bottom =
        KSize.contentBottomPad + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (query.isNotEmpty &&
                n.metrics.axis == Axis.vertical &&
                n.metrics.extentAfter < 600) {
              ref.read(remoteSearchProvider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              const SliverToBoxAdapter(child: KScreenHeader(title: 'Search')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter,
                  0,
                  KSpace.gutter,
                  KSpace.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: KSearchField(
                    key: const Key('search-field'),
                    hint: 'Titles, speakers, passages',
                    controller: _controller,
                    autofocus: true,
                    onChanged: (q) =>
                        ref.read(sermonSearchProvider.notifier).state = q,
                    onSubmitted: (_) => _remember(),
                    trailing: _controller.text.isEmpty
                        ? null
                        : KIconButton(
                            key: const Key('search-clear'),
                            icon: KIcons.close,
                            label: 'Clear search',
                            onPressed: () => setState(() => _setQuery('')),
                          ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: KSpace.section),
                  child: KChipRow(
                    key: const Key('search-filters'),
                    children: [
                      KChip(
                        key: const ValueKey('search-filter-sort'),
                        label: _sort == SearchSort.relevant
                            ? 'Sort'
                            : _sort.label,
                        selected: _sort != SearchSort.relevant,
                        showChevron: true,
                        onTap: () => unawaited(_openSort()),
                      ),
                      for (final f in SearchFilter.values)
                        if (f != SearchFilter.book || hasBooks)
                          KChip(
                            key: ValueKey('search-filter-${f.name}'),
                            label: _chipLabel(f),
                            selected: (_filters[f] ?? const {}).isNotEmpty,
                            showChevron: true,
                            onTap: () => unawaited(_openFilter(f)),
                          ),
                    ],
                  ),
                ),
              ),
              if (query.isEmpty && !filtering)
                _Recent(
                  searches: recent,
                  onPick: (q) => setState(() => _setQuery(q)),
                  onRemove: ref.read(recentSearchesProvider.notifier).remove,
                  onClear: ref.read(recentSearchesProvider.notifier).clear,
                )
              else if (results.isEmpty && loading)
                const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (results.isEmpty)
                SliverToBoxAdapter(
                  child: KEmptyState(
                    key: const Key('search-empty'),
                    icon: KIcons.search,
                    title: 'No messages found',
                    hint: filtering
                        ? 'Try fewer filters or another word.'
                        : 'Try another word, a speaker or a passage.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpace.gutter,
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: KSpace.lg),
                          child: Text(
                            '${results.length == 1 ? '1 message' : '${results.length} messages'}'
                            ' \u00b7 Sorted by ${_sort.label.toLowerCase()}',
                            key: const Key('search-count'),
                            style: KharisText.meta.copyWith(
                              color: context.k.muted,
                            ),
                          ),
                        ),
                      ),
                      KSliverListGroup(
                        key: const Key('search-results'),
                        itemCount: results.length,
                        itemBuilder: (context, i) => Listener(
                          onPointerDown: (_) => _remember(),
                          child: MessageRow(
                            key: ValueKey('search-${results[i].id}'),
                            sermon: results[i],
                            queue: results,
                          ),
                        ),
                      ),
                    ],
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

class _Recent extends StatelessWidget {
  const _Recent({
    required this.searches,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> searches;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) return const SliverToBoxAdapter();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      sliver: SliverList.list(
        key: const Key('search-recent'),
        children: [
          KSectionHeader(
            title: 'Recent searches',
            actionLabel: 'Clear',
            onAction: onClear,
          ),
          KListGroup(
            children: [
              for (final q in searches)
                KListRow(
                  key: ValueKey('recent-$q'),
                  title: q,
                  leading: const KIconTile(KIcons.search),
                  trailing: KIconButton(
                    icon: KIcons.close,
                    label: 'Remove $q',
                    onPressed: () => onRemove(q),
                  ),
                  onTap: () => onPick(q),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
