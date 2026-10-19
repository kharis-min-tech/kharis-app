import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Opens the Messages filter sheet. Resolves `true` when the member tapped
/// Apply; dismissing the sheet changes nothing.
Future<bool> showMessageFiltersSheet(BuildContext context) async {
  final applied = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const MessageFiltersSheet(),
  );
  return applied ?? false;
}

/// How many of the sheet's filters (year, series, speaker) are active: the
/// count on the Filters button. Sort is an order, not a filter.
int activeSheetFilterCount(WidgetRef ref) => [
  ref.watch(selectedArchiveYearProvider),
  ref.watch(selectedSeriesProvider),
  ref.watch(selectedSpeakerProvider),
].where((v) => v != null).length;

/// Sort, year, speaker and series for the library list. Choices stay a draft
/// until Apply writes them to the providers; Reset clears the draft.
class MessageFiltersSheet extends ConsumerStatefulWidget {
  const MessageFiltersSheet({super.key});

  @override
  ConsumerState<MessageFiltersSheet> createState() =>
      _MessageFiltersSheetState();
}

class _MessageFiltersSheetState extends ConsumerState<MessageFiltersSheet> {
  /// Speakers shown before "Show all".
  static const _speakerPreview = 8;

  /// Series beyond this many get a search field.
  static const _seriesSearchFrom = 8;

  late SermonSort _sort;
  late int? _year;
  late String? _series;
  late String? _speaker;
  bool _allSpeakers = false;
  final _seriesQuery = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sort = ref.read(sermonSortProvider);
    _year = ref.read(selectedArchiveYearProvider);
    _series = ref.read(selectedSeriesProvider);
    _speaker = ref.read(selectedSpeakerProvider);
    _seriesQuery.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _seriesQuery.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _sort = SermonSort.newest;
    _year = null;
    _series = null;
    _speaker = null;
    _seriesQuery.clear();
  });

  void _apply() {
    ref.read(sermonSortProvider.notifier).state = _sort;
    ref.read(selectedArchiveYearProvider.notifier).state = _year;
    ref.read(selectedSeriesProvider.notifier).state = _series;
    ref.read(selectedSpeakerProvider.notifier).state = _speaker;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final years = ref.watch(archiveYearsProvider);
    final yearCounts = ref.watch(archiveYearCountsProvider);
    final speakers = ref.watch(speakerListProvider);
    final allSeries = ref.watch(seriesListProvider);

    final words = normaliseForSearch(
      _seriesQuery.text,
    ).split(' ').where((w) => w.isNotEmpty).toList();
    final series = words.isEmpty
        ? allSeries
        : [
            for (final s in allSeries)
              if (words.every(normaliseForSearch(s.name).contains)) s,
          ];

    // The picked speaker stays visible even when it ranks past the preview.
    final shownSpeakers = _allSpeakers || speakers.length <= _speakerPreview
        ? speakers
        : [
            ...speakers.take(_speakerPreview),
            ...speakers.skip(_speakerPreview).where((s) => s.name == _speaker),
          ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Material(
            color: kc.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kc.outline,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(
                    'Filters',
                    style: AppTypography.display(
                      size: 18,
                      weight: FontWeight.w700,
                      color: kc.onBg,
                    ),
                  ),
                ),
                Flexible(
                  child: CustomScrollView(
                    key: const Key('message-filters-scroll'),
                    shrinkWrap: true,
                    slivers: [
                      _section(
                        'Sort',
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final s in [
                              SermonSort.newest,
                              SermonSort.oldest,
                            ])
                              FilterChoicePill(
                                label: s.label,
                                active: _sort == s,
                                onTap: () => setState(() => _sort = s),
                              ),
                          ],
                        ),
                      ),
                      if (years.length > 1)
                        _section(
                          'Year',
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChoicePill(
                                label: 'All years',
                                active: _year == null,
                                onTap: () => setState(() => _year = null),
                              ),
                              for (final y in years)
                                FilterChoicePill(
                                  label: '$y (${yearCounts[y] ?? 0})',
                                  active: _year == y,
                                  onTap: () => setState(
                                    () => _year = _year == y ? null : y,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (speakers.length > 1)
                        _section(
                          'Speaker',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilterChoicePill(
                                    label: 'All speakers',
                                    active: _speaker == null,
                                    onTap: () =>
                                        setState(() => _speaker = null),
                                  ),
                                  for (final s in shownSpeakers)
                                    FilterChoicePill(
                                      label: '${s.name} (${s.count})',
                                      active: _speaker == s.name,
                                      onTap: () => setState(
                                        () => _speaker = _speaker == s.name
                                            ? null
                                            : s.name,
                                      ),
                                    ),
                                ],
                              ),
                              if (speakers.length > _speakerPreview)
                                TextButton(
                                  onPressed: () => setState(
                                    () => _allSpeakers = !_allSpeakers,
                                  ),
                                  child: Text(
                                    _allSpeakers
                                        ? 'Show fewer'
                                        : 'Show all ${speakers.length} '
                                              'speakers',
                                    style: AppTypography.labelMd.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: kc.accentInk,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (allSeries.isNotEmpty) ...[
                        _section(
                          'Series',
                          allSeries.length > _seriesSearchFrom
                              ? _SeriesSearchField(controller: _seriesQuery)
                              : null,
                        ),
                        SliverToBoxAdapter(
                          child: _SeriesOption(
                            name: 'All series',
                            selected: _series == null,
                            onTap: () => setState(() => _series = null),
                          ),
                        ),
                        if (series.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                12,
                              ),
                              child: Text(
                                'No series match "${_seriesQuery.text.trim()}"',
                                style: AppTypography.bodySm.copyWith(
                                  color: kc.muted,
                                ),
                              ),
                            ),
                          )
                        else
                          SliverList.builder(
                            itemCount: series.length,
                            itemBuilder: (context, i) {
                              final s = series[i];
                              return _SeriesOption(
                                key: ValueKey('series-option-${s.name}'),
                                name: s.name,
                                count: s.count,
                                selected: _series == s.name,
                                onTap: () => setState(
                                  () => _series = _series == s.name
                                      ? null
                                      : s.name,
                                ),
                              );
                            },
                          ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: kc.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('message-filters-reset'),
                        onPressed: _reset,
                        child: Text(
                          'Reset',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kc.onBg,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        key: const Key('message-filters-apply'),
                        onPressed: _apply,
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A labelled block of the sheet; [body] may be null for a bare label.
  Widget _section(String title, Widget? body) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    sliver: SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w800,
              color: context.kc.muted,
              letterSpacing: 0.2,
            ),
          ),
          if (body != null) ...[const SizedBox(height: 4), body],
        ],
      ),
    ),
  );
}

// ── Series search ─────────────────────────────────────────────────────────────

class _SeriesSearchField extends StatelessWidget {
  const _SeriesSearchField({required this.controller});

  final TextEditingController controller;

  static OutlineInputBorder _border(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    borderSide: side,
  );

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: TextField(
        key: const Key('message-filters-series-search'),
        controller: controller,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyLg.copyWith(color: kc.onBg),
        cursorColor: kc.accentInk,
        decoration: InputDecoration(
          hintText: 'Search series',
          hintStyle: AppTypography.bodySm.copyWith(color: kc.muted),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: kc.muted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear series search',
                  onPressed: controller.clear,
                  icon: Icon(Icons.close_rounded, size: 18, color: kc.muted),
                ),
          border: _border(BorderSide.none),
          enabledBorder: _border(BorderSide.none),
          focusedBorder: _border(BorderSide(color: kc.accentInk, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
          filled: true,
          fillColor: kc.surfaceAlt,
        ),
      ),
    );
  }
}

// ── Series row ────────────────────────────────────────────────────────────────

class _SeriesOption extends StatelessWidget {
  const _SeriesOption({
    super.key,
    required this.name,
    this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ui(
                      size: 15,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: kc.onBg,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '$count',
                    style: AppTypography.ui(size: 13, color: kc.muted),
                  ),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 22,
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: kc.accentInk,
                          size: 22,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Choice pill (gold active, muted surface inactive) ─────────────────────────

/// One choice in a sheet section. Selection is announced, not only
/// coloured; the slack around the pill widens its tap target.
class FilterChoicePill extends StatelessWidget {
  const FilterChoicePill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? kc.accent : kc.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? kc.onAccent : kc.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
