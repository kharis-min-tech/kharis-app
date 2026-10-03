import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/features/admin/providers/content_config_providers.dart';
import 'package:kharis_app/features/home/data/reading_plan.dart'
    show dateOnly, parseReadingDate;
import 'package:kharis_app/features/messages/data/curation_repository.dart'
    show FeaturedMode;
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Messages tab curation in the Content Studio: how the featured carousel is
/// filled (`config/featured`) and which message is the Message of the Day on
/// each date (`motdSchedule/{YYYY-MM-DD}`, device-local dates).

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

/// Auto (the newest uploads) or Pinned (the starred sermons below).
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
                label: Text('Auto (latest uploads)'),
              ),
              ButtonSegment(value: FeaturedMode.pinned, label: Text('Pinned')),
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
          _muted('Stars only apply in Pinned mode.'),
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
      _snack(
        messenger,
        mode == FeaturedMode.auto
            ? 'Featured now shows the latest uploads.'
            : 'Featured now shows your starred sermons.',
      );
    } catch (e) {
      _snack(messenger, 'Could not change Featured: $e', error: true);
    }
  }
}

// ── Message of the Day ────────────────────────────────────────────────────────

/// Schedules a message for a chosen date and lists what is coming up.
class MotdScheduleCard extends ConsumerStatefulWidget {
  const MotdScheduleCard({super.key});

  @override
  ConsumerState<MotdScheduleCard> createState() => _MotdScheduleCardState();
}

class _MotdScheduleCardState extends ConsumerState<MotdScheduleCard> {
  DateTime _date = dateOnly(DateTime.now());
  bool _busy = false;

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await pickStudioDate(
      context,
      initial: _date,
      first: today,
      last: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) setState(() => _date = dateOnly(picked));
  }

  Future<void> _chooseMessage() async {
    final messenger = ScaffoldMessenger.of(context);
    final date = _date;
    final sermon = await showModalBottomSheet<Sermon>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MotdSermonPickerSheet(),
    );
    if (sermon == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(contentConfigRepositoryProvider)
          .scheduleMotd(date: date, sermonId: sermon.id, title: sermon.title);
      _snack(
        messenger,
        '"${sermon.title}" is the Message of the Day on ${studioDayLabel(date)}.',
      );
    } catch (e) {
      _snack(messenger, 'Could not schedule: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear(MotdEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final date = parseReadingDate(entry.dateKey);
    if (date == null) return;
    try {
      await ref.read(contentConfigRepositoryProvider).clearMotd(date);
      _snack(messenger, 'Cleared ${studioDayLabel(date)}.');
    } catch (e) {
      _snack(messenger, 'Could not clear: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(adminMotdScheduleProvider);
    final today = dateOnly(DateTime.now());

    return _CurationCard(
      title: 'Message of the Day',
      children: [
        Row(
          children: [
            Expanded(
              child: StudioPickerButton(
                label: _date == today
                    ? 'Today, ${studioDayLabel(_date)}'
                    : studioDayLabel(_date),
                hasValue: true,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton(
              onPressed: _busy ? null : _chooseMessage,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonBorder,
                ),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onSecondary,
                      ),
                    )
                  : const Text('Choose message'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        schedule.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: LinearProgressIndicator(color: AppColors.secondary),
          ),
          error: (_, _) => Row(
            children: [
              Expanded(child: _muted('Could not load the schedule.')),
              TextButton(
                onPressed: () => ref.invalidate(adminMotdScheduleProvider),
                child: Text(
                  'Retry',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          data: (entries) => entries.isEmpty
              ? _muted('Nothing scheduled yet.')
              : Column(children: [for (final entry in entries) _row(entry)]),
        ),
        _muted(
          'Days without a scheduled message use an automatic pick from '
          'the last 90 days.',
        ),
      ],
    );
  }

  Widget _row(MotdEntry entry) {
    final date = parseReadingDate(entry.dateKey);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              date == null ? entry.dateKey : studioDayLabel(date),
              style: AppTypography.labelMd.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.title.isEmpty ? 'Message ${entry.sermonId}' : entry.title,
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.onSurfaceVariant,
            tooltip: 'Clear',
            onPressed: () => _clear(entry),
          ),
        ],
      ),
    );
  }
}

/// Searchable list of playable messages (non-empty audio), newest first.
/// Pops the chosen [Sermon].
///
/// The bundled offline catalogue (`archive_*` ids, shown while the API is
/// unreachable) is never offered: members online cannot resolve those ids,
/// so the day would silently fall back to the automatic pick.
class MotdSermonPickerSheet extends ConsumerStatefulWidget {
  const MotdSermonPickerSheet({super.key});

  @override
  ConsumerState<MotdSermonPickerSheet> createState() =>
      _MotdSermonPickerSheetState();
}

class _MotdSermonPickerSheetState extends ConsumerState<MotdSermonPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Sermon> _filter(List<Sermon> sermons) {
    final q = _query.trim().toLowerCase();
    final playable =
        sermons
            .where((s) => s.audioUrl.trim().isNotEmpty)
            .where((s) => s.source != 'archive')
            .where(
              (s) =>
                  q.isEmpty ||
                  s.title.toLowerCase().contains(q) ||
                  s.speaker.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            final da = a.publishedAt;
            final db = b.publishedAt;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });
    return playable;
  }

  @override
  Widget build(BuildContext context) {
    final sermons = ref.watch(sermonsProvider);
    // The library is serving its bundled offline catalogue.
    final offline =
        sermons.valueOrNull?.any((s) => s.source == 'archive') ?? false;
    final dateFmt = DateFormat('d MMM y');

    // A Material surface (not a coloured box) so the ListTiles' ink shows.
    return Material(
      color: AppColors.surfaceDark,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Choose message',
              style: AppTypography.titleMd.copyWith(color: AppColors.heading),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
              decoration: studioInputDecoration(hint: 'Search title or speaker')
                  .copyWith(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
              onChanged: (value) => setState(() => _query = value),
            ),
            if (offline)
              _muted(
                'The sermon library is offline, so only Studio messages can '
                'be chosen. Try again once it reconnects.',
              ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: sermons.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                ),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load messages.',
                        style: AppTypography.bodyLg.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(sermonsProvider),
                        child: Text(
                          'Retry',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (all) {
                  final matches = _filter(all);
                  if (matches.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages match.',
                        style: AppTypography.bodyLg.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: AppColors.outlineVariant,
                      height: 1,
                      thickness: 0.5,
                    ),
                    itemBuilder: (_, index) {
                      final sermon = matches[index];
                      final date = sermon.publishedAt;
                      final meta = [
                        if (date != null) dateFmt.format(date),
                        if (sermon.speaker.trim().isNotEmpty) sermon.speaker,
                      ].join(' · ');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          sermon.title,
                          style: AppTypography.bodyLg.copyWith(
                            color: AppColors.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: meta.isEmpty
                            ? null
                            : Text(
                                meta,
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                        onTap: () => Navigator.pop(context, sermon),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
