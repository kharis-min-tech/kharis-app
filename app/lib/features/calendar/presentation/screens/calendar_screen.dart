import 'package:add_2_calendar_new/add_2_calendar_new.dart' as add2cal;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
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

  /// True once the member has picked a branch on this screen. Kept separate
  /// from [_branchOverride] so "all campuses" (a `null` branch) is a real
  /// choice rather than indistinguishable from "not chosen yet".
  bool _branchOverridden = false;
  String? _branchOverride;

  @override
  Widget build(BuildContext context) {
    final branch = _branchOverridden
        ? _branchOverride
        : ref.watch(currentBranchProvider).valueOrNull;
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
        );
      case _EventTab.rsvps:
        if (ref.watch(currentUserProvider).valueOrNull == null) {
          return _signInSliver(
            title: 'Sign in to see your RSVPs',
            subtitle: 'Your RSVPs are saved to your account so they follow '
                'you between devices.',
          );
        }
        return _eventsSliver(
          ref.watch(myRsvpEventsProvider),
          emptyIcon: Icons.check_circle_outline_rounded,
          emptyTitle: 'No RSVPs yet',
          emptySubtitle: 'Events you RSVP to will show up here.',
        );
    }
  }

  Widget _eventsSliver(
    AsyncValue<List<Event>> async, {
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
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
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _EventCard(
                  event: events[index],
                  accent: _accentPalette[index % _accentPalette.length],
                ),
              ),
              childCount: events.length,
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
    setState(() {
      _branchOverridden = true;
      _branchOverride = choice.name;
    });
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

// ── Header ───────────────────────────────────────────────────────────────────

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      branchLabel,
                      style: AppTypography.ui(size: 13, weight: FontWeight.w600)
                          .copyWith(color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.primary),
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Show events for',
                  style: AppTypography.ui(size: 15, weight: FontWeight.w700)
                      .copyWith(color: context.kc.onBg),
                ),
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

// ── Event card ─────────────────────────────────────────────────────────────────

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.accent});

  final Event event;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = DateFormat('d').format(event.startTime);
    final month = DateFormat('MMM').format(event.startTime).toUpperCase();
    final weekday = DateFormat('EEE').format(event.startTime);
    final time = DateFormat('h:mm a').format(event.startTime);
    final whenText = '$weekday \u00b7 $time';
    final place = event.location ?? event.branch ?? '';
    final isPast = event.isPastAt(DateTime.now());
    final isRsvped = ref.watch(isEventRsvpedProvider(event.id));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo banner with overlaid date chip.
          Stack(
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: _banner(),
              ),
              Positioned(
                top: 11,
                left: 11,
                child: _DateChip(day: day, month: month, color: accent),
              ),
              if (event.isFeatured)
                const Positioned(top: 11, right: 11, child: _FeaturedPill()),
            ],
          ),

          // Title + time + location.
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTypography.ui(
                    size: 15.5,
                    weight: FontWeight.w700,
                    height: 1.15,
                  ).copyWith(color: context.kc.onBg),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.schedule_rounded, text: whenText),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _InfoRow(icon: Icons.place_outlined, text: place),
                ],
              ],
            ),
          ),

          // Split footer: RSVP | Add to calendar.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.kc.divider)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: isPast
                        ? _FooterAction(
                            label: 'Ended',
                            color: context.kc.muted,
                            onTap: null,
                          )
                        : _FooterAction(
                            label: isRsvped ? 'Going \u2713' : 'RSVP',
                            color: isRsvped
                                ? context.kc.muted
                                : AppColors.primary,
                            onTap: () => _toggleRsvp(context, ref),
                          ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: context.kc.divider,
                  ),
                  Expanded(
                    child: _FooterAction(
                      label: 'Add to calendar',
                      color: context.kc.muted,
                      onTap: () => _addToCalendar(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.85),
            AppColors.primaryDeep,
          ],
        ),
      ),
    );
    final url = event.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  /// Toggles the persisted RSVP. The button state comes from
  /// [isEventRsvpedProvider], which is driven by the Firestore stream, so the
  /// UI settles on the value that was actually written.
  Future<void> _toggleRsvp(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (ref.read(currentUserProvider).valueOrNull == null) {
      _promptSignIn(messenger, router);
      return;
    }
    final activeBranch = ref.read(currentBranchProvider).valueOrNull;
    try {
      final going = await ref
          .read(rsvpRepositoryProvider)
          .toggleRsvp(event, branch: event.branch ?? activeBranch);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_toast(going
            ? 'You\u2019re going to ${event.title} \ud83c\udf89'
            : 'RSVP cancelled for ${event.title}.'));
    } on RsvpAuthRequiredException {
      _promptSignIn(messenger, router);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_toast('Couldn\u2019t save your RSVP. Please try again.'));
    }
  }

  void _promptSignIn(ScaffoldMessengerState messenger, GoRouter router) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(_toast(
        'Sign in to RSVP to events.',
        action: SnackBarAction(
          label: 'Sign in',
          onPressed: () => router.push('/login'),
        ),
      ));
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Events may legitimately have no end time; a one-hour block is the
    // sensible default for a calendar entry.
    final calEvent = add2cal.Event(
      title: event.title,
      description: event.description,
      location: event.location,
      startDate: event.startTime,
      endDate: event.endTime ?? event.startTime.add(const Duration(hours: 1)),
    );
    try {
      await add2cal.Add2Calendar.addEvent2Cal(calEvent);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_toast('Couldn\u2019t open your calendar.'));
    }
  }
}

class _FeaturedPill extends StatelessWidget {
  const _FeaturedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            'Featured',
            style: AppTypography.ui(
              size: 10,
              weight: FontWeight.w700,
              letterSpacing: 0.3,
            ).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.day,
    required this.month,
    required this.color,
  });

  final String day;
  final String month;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Fixed light plate in both themes. The chip sits on the photo banner, and
    // the _accentPalette it carries is calibrated for a light plate over
    // photography — tinting it with the active surface drops those accents to
    // roughly 2:1 in dark mode.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: AppTypography.ui(size: 18, weight: FontWeight.w700, height: 1)
                .copyWith(color: color),
          ),
          Text(
            month,
            style: AppTypography.ui(
              size: 9,
              weight: FontWeight.w600,
              letterSpacing: 0.4,
            ).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: context.kc.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: AppTypography.ui(size: 12.5)
                .copyWith(color: context.kc.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;

  /// `null` renders the action as inert — used for events that have ended.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            label,
            style: AppTypography.ui(size: 13, weight: FontWeight.w700)
                .copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

// ── Toast ─────────────────────────────────────────────────────────────────────

/// Toast. Plate colour, content type, floating behaviour and shape all come
/// from `snackBarTheme`; only the bottom margin that clears the tab bar is
/// screen-specific.
SnackBar _toast(String message, {SnackBarAction? action}) => SnackBar(
      content: Text(message),
      action: action,
      duration: const Duration(milliseconds: 1900),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
    );
