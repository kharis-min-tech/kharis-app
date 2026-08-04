import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Events tab (design-handoff v3). Segmented Upcoming / Past /
/// My RSVPs tabs, a branch selector, and event cards with a photo banner, an
/// overlaid date chip, title/time/location, and RSVP + Add-to-calendar actions.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

enum _EventTab { upcoming, past, rsvps }

/// Label used wherever the active branch is `null` (unscoped).
const String _kAllCampuses = 'All campuses';

/// Date-chip accent colours cycled per card (mirrors the prototype palette).
const List<Color> _accentPalette = [
  AppColors.primary, // purple
  Color(0xFFB91C5C), // rose
  Color(0xFFE09B1F), // gold-deep
  Color(0xFF137A6D), // teal
];

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _EventTab _tab = _EventTab.upcoming;

  @override
  Widget build(BuildContext context) {
    // The member's campus is persisted state, never screen state: this screen
    // reads it from [currentBranchProvider] and writes it back through
    // [setActiveBranch]. A local override field here would be a second source
    // of truth that dies with the screen — which is exactly how the chip used
    // to appear to "revert" on relaunch.
    final branch = ref.watch(currentBranchProvider).valueOrNull;
    final branchLabel = branch ?? _kAllCampuses;
    final branches = ref.watch(branchesProvider).valueOrNull ??
        BranchRepository.seedBranches;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      branchLabel: branchLabel,
                      onTapBranch: () => _pickBranch(branches, branch),
                    ),
                    const SizedBox(height: 16),
                    _SegmentedTabs(
                      selected: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _tabSliver(branch: branch, branchLabel: branchLabel),
          ],
        ),
      ),
    );
  }

  Widget _tabSliver({required String? branch, required String branchLabel}) {
    switch (_tab) {
      case _EventTab.upcoming:
        return _eventsSliver(
          ref.watch(upcomingEventsProvider(branch)),
          emptyIcon: Icons.event_busy_outlined,
          emptyTitle: 'No upcoming events',
          emptySubtitle: 'Check back soon for events at $branchLabel.',
        );
      case _EventTab.past:
        return _eventsSliver(
          ref.watch(pastEventsProvider(branch)),
          emptyIcon: Icons.history_rounded,
          emptyTitle: 'No past events',
          emptySubtitle: 'Events at $branchLabel that have finished '
              'will appear here.',
          capNote: 'Showing the ${EventRepository.pastEventLimit} most recent '
              'events. Anything older is no longer listed.',
        );
      case _EventTab.rsvps:
        if (ref.watch(currentUserProvider).valueOrNull == null) {
          return _signInSliver(
            title: 'Sign in to see your RSVPs',
            subtitle: 'Your RSVPs are saved to your account so they follow '
                'you between devices.',
          );
        }
        return _rsvpSliver(ref.watch(myRsvpEventsProvider));
    }
  }

  /// [capNote] is shown under the list once it is full to the view cap, so a
  /// truncated archive never reads as the whole history.
  Widget _eventsSliver(
    AsyncValue<List<Event>> async, {
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    String? capNote,
  }) {
    return async.when(
      loading: () => _kLoadingSliver,
      error: (_, _) => _messageSliver(
        context,
        icon: Icons.error_outline_rounded,
        title: 'Unable to load events',
        subtitle: 'Please check your connection and try again.',
      ),
      data: (events) {
        if (events.isEmpty) {
          return _messageSliver(
            context,
            icon: emptyIcon,
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }
        final note = events.length >= EventRepository.pastEventLimit
            ? capNote
            : null;
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == events.length) return _CapNote(text: note!);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: EventCard(
                    event: events[index],
                    accent: _accentPalette[index % _accentPalette.length],
                  ),
                );
              },
              childCount: events.length + (note == null ? 0 : 1),
            ),
          ),
        );
      },
    );
  }

  /// "My RSVPs" is sectioned rather than flat: an RSVP'd event whose date has
  /// passed belongs under Past, never Upcoming. A group with no events
  /// contributes no header.
  Widget _rsvpSliver(AsyncValue<RsvpEvents> async) {
    return async.when(
      loading: () => _kLoadingSliver,
      error: (_, _) => _messageSliver(
        context,
        icon: Icons.error_outline_rounded,
        title: 'Unable to load your RSVPs',
        subtitle: 'Please check your connection and try again.',
      ),
      data: (grouped) {
        if (grouped.isEmpty) {
          return _messageSliver(
            context,
            icon: Icons.check_circle_outline_rounded,
            title: 'No RSVPs yet',
            subtitle: 'Events you RSVP to will show up here.',
          );
        }
        final rows = _rsvpRows(grouped);
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => switch (rows[index]) {
                _RsvpHeaderRow(:final label) => _GroupHeader(label: label),
                _RsvpCardRow(:final event, :final accent) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: EventCard(event: event, accent: accent),
                  ),
                _RsvpNoteRow(:final text) => _CapNote(text: text),
              },
              childCount: rows.length,
            ),
          ),
        );
      },
    );
  }

  Widget _signInSliver({required String title, required String subtitle}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 150),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                color: context.kc.muted, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                  .copyWith(color: context.kc.onBg),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTypography.ui(size: 13)
                  .copyWith(color: context.kc.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder),
              ),
              onPressed: () => context.push('/login'),
              child: Text(
                'Sign in',
                style: AppTypography.ui(size: 14, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Switches the member's campus for the whole app.
  ///
  /// [setActiveBranch] owns every store the campus lives in — the local
  /// preference, this device's FCM branch topic and `users/{uid}.branch` —
  /// and invalidates [currentBranchProvider] on the way out. None of that is
  /// repeated here, and nothing is kept on this screen.
  Future<void> _pickBranch(List<Branch> branches, String? current) async {
    final choice = await showModalBottomSheet<_BranchChoice>(
      context: context,
      backgroundColor: context.kc.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _BranchSheet(
        branchNames: branches.map((b) => b.name).toList(growable: false),
        current: current,
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.name == current) return;
    final messenger = ScaffoldMessenger.of(context);
    final label = choice.name ?? _kAllCampuses;
    final result = await setActiveBranch(ref, choice.name);
    if (!mounted) return;
    messenger.showSnackBar(
      eventToast(
        result.syncFailed
            ? 'Your campus is now $label on this device. We could not reach '
                'your profile — it will sync automatically.'
            : 'Your campus is now $label.',
      ),
    );
  }
}

/// A branch picked from the sheet. Wraps the name so "all campuses"
/// (`name == null`) is distinguishable from "dismissed without choosing".
@immutable
class _BranchChoice {
  const _BranchChoice(this.name);
  final String? name;
}

Widget _messageSliver(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 150),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.kc.muted, size: 44),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                .copyWith(color: context.kc.onBg),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTypography.ui(size: 13)
                .copyWith(color: context.kc.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

const Widget _kLoadingSliver = SliverToBoxAdapter(
  child: Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2,
      ),
    ),
  ),
);

// ── My RSVPs sections ─────────────────────────────────────────────────────────

/// One row of the sectioned "My RSVPs" list.
sealed class _RsvpRow {
  const _RsvpRow();
}

class _RsvpHeaderRow extends _RsvpRow {
  const _RsvpHeaderRow(this.label);

  final String label;
}

class _RsvpCardRow extends _RsvpRow {
  const _RsvpCardRow(this.event, this.accent);

  final Event event;
  final Color accent;
}

class _RsvpNoteRow extends _RsvpRow {
  const _RsvpNoteRow(this.text);

  final String text;
}

/// Flattens [grouped] into header + card rows. The accent palette continues
/// across both groups so no two adjacent cards share a colour.
///
/// The Past group is capped at [EventRepository.pastEventLimit] by
/// [myRsvpEventsProvider]; when it is full, a closing note says so rather
/// than letting a truncated list pass for the member's whole RSVP history.
List<_RsvpRow> _rsvpRows(RsvpEvents grouped) {
  final rows = <_RsvpRow>[];
  var accent = 0;

  void addGroup(String label, List<Event> events) {
    if (events.isEmpty) return;
    rows.add(_RsvpHeaderRow(label));
    for (final event in events) {
      rows.add(
        _RsvpCardRow(event, _accentPalette[accent++ % _accentPalette.length]),
      );
    }
  }

  addGroup('Upcoming', grouped.upcoming);
  addGroup('Past', grouped.past);
  if (grouped.past.length >= EventRepository.pastEventLimit) {
    rows.add(
      _RsvpNoteRow(
        'Showing your ${EventRepository.pastEventLimit} most recent past '
        'RSVPs.',
      ),
    );
  }
  return rows;
}

/// Closing line under a list that has been trimmed to a view cap. Quiet by
/// design: it explains an absence, it is not content.
class _CapNote extends StatelessWidget {
  const _CapNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.ui(size: 12).copyWith(color: context.kc.faint),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.ui(
          size: 11,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
        ).copyWith(color: context.kc.muted),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

/// Screen title plus the campus chip. The chip is captioned "YOUR CAMPUS"
/// because tapping it changes the member's campus everywhere — it is not a
/// throwaway filter over this list.
class _Header extends StatelessWidget {
  const _Header({required this.branchLabel, required this.onTapBranch});

  final String branchLabel;
  final VoidCallback onTapBranch;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Events',
            style: AppTypography.display(size: 27, weight: FontWeight.w700)
                .copyWith(color: context.kc.onBg),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: GestureDetector(
            onTap: onTapBranch,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: context.kc.surface,
                borderRadius: AppRadius.pillBorder,
                boxShadow: AppShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR CAMPUS',
                    style: AppTypography.ui(
                      size: 9,
                      weight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ).copyWith(color: context.kc.muted),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          branchLabel,
                          style: AppTypography.ui(
                            size: 13,
                            weight: FontWeight.w600,
                          ).copyWith(color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Branch sheet ──────────────────────────────────────────────────────────────

class _BranchSheet extends StatelessWidget {
  const _BranchSheet({required this.branchNames, required this.current});

  final List<String> branchNames;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.kc.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your campus',
                    style: AppTypography.ui(size: 15, weight: FontWeight.w700)
                        .copyWith(color: context.kc.onBg),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved to your profile and used across the app — events, '
                    'announcements and giving. You can change it any time.',
                    style: AppTypography.ui(size: 12)
                        .copyWith(color: context.kc.muted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  _tile(context, label: _kAllCampuses, value: null),
                  for (final name in branchNames)
                    _tile(context, label: name, value: name),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required String label, required String? value}) {
    final selected = value == current;
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: AppTypography.ui(
          size: 14,
          weight: selected ? FontWeight.w700 : FontWeight.w500,
        ).copyWith(
          color: selected ? AppColors.primary : context.kc.onBg,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
          : null,
      onTap: () => Navigator.of(context).pop(_BranchChoice(value)),
    );
  }
}

// ── Segmented tabs ────────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onChanged});

  final _EventTab selected;
  final ValueChanged<_EventTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip(
          label: 'Upcoming',
          active: selected == _EventTab.upcoming,
          onTap: () => onChanged(_EventTab.upcoming),
        ),
        const SizedBox(width: 9),
        _TabChip(
          label: 'Past',
          active: selected == _EventTab.past,
          onTap: () => onChanged(_EventTab.past),
        ),
        const SizedBox(width: 9),
        _TabChip(
          label: 'My RSVPs',
          active: selected == _EventTab.rsvps,
          onTap: () => onChanged(_EventTab.rsvps),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : context.kc.surfaceMuted,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Text(
          label,
          style: AppTypography.ui(
            size: 13,
            weight: active ? FontWeight.w700 : FontWeight.w600,
          ).copyWith(
            color: active ? AppColors.onPrimary : context.kc.muted,
          ),
        ),
      ),
    );
  }
}

