import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The events list (`/calendar`): the branch it lists, Upcoming / Past /
/// My RSVPs tabs, and one card per event with "Remind me".
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

enum _EventTab {
  upcoming('Upcoming'),
  past('Past'),
  rsvps('My RSVPs');

  const _EventTab(this.label);

  final String label;
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _EventTab _tab = _EventTab.upcoming;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    // The member's branch is persisted state, read from
    // [currentBranchProvider] and written through [setActiveBranch]. The
    // only screen-level choice is the session "All branches" browse filter
    // ([eventsShowAllBranchesProvider]), which never becomes their branch.
    final branch = ref.watch(eventsBranchProvider).valueOrNull;
    final branchLabel = branch ?? kAllCampusesLabel;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: RefreshIndicator(
              color: k.primaryText,
              backgroundColor: k.surface,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: KSpace.md),
                        const KScreenHeader(title: 'Events'),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpace.gutter,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: KTextLink(
                              label: branch != null
                                  ? 'Your branch \u00b7 $branchLabel'
                                  : 'Showing \u00b7 $branchLabel',
                              semanticLabel: branch != null
                                  ? 'Your branch: $branchLabel. Change branch'
                                  : 'Showing $branchLabel. Change branch',
                              showChevron: true,
                              onTap: _pickBranch,
                            ),
                          ),
                        ),
                        const SizedBox(height: KSpace.md),
                        KTabs(
                          tabs: [for (final t in _EventTab.values) t.label],
                          currentIndex: _tab.index,
                          onChanged: (i) =>
                              setState(() => _tab = _EventTab.values[i]),
                        ),
                      ],
                    ),
                  ),
                  _tabSliver(branchLabel: branchLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The shared branch sheet plus the "All branches" browse row. A branch
  /// becomes the member's branch everywhere (and ends browsing); "All
  /// branches" only widens this list for the session.
  Future<void> _pickBranch() async {
    final showAll = ref.read(eventsShowAllBranchesProvider);
    final choice = await showBranchPicker(
      context,
      current: showAll ? null : ref.read(currentBranchProvider).valueOrNull,
      allowAll: true,
    );
    if (choice == null || !mounted) return;
    final name = choice.name;
    ref.read(eventsShowAllBranchesProvider.notifier).state = name == null;
    if (name != null) await applyBranchChoice(context, ref, name);
  }

  /// Reloads the visible tab and holds the spinner until it has answered.
  Future<void> _refresh() {
    switch (_tab) {
      case _EventTab.upcoming:
        return refreshEventsContent(ref);
      case _EventTab.past:
        return refreshEventsContent(ref, pastEvents: true);
      case _EventTab.rsvps:
        return settleRefresh(ref.refresh(myRsvpEventsProvider.future));
    }
  }

  void _show(_EventTab tab) => setState(() => _tab = tab);

  Widget _tabSliver({required String branchLabel}) {
    switch (_tab) {
      case _EventTab.upcoming:
        return _eventsSliver(
          ref.watch(eventsUpcomingProvider),
          empty: KEmptyState(
            icon: KIcons.calendar,
            title: 'No upcoming events',
            hint: 'Check back soon for events at $branchLabel.',
            // Not a dead end: past events are one tap away.
            action: KButton(
              label: 'See past events',
              variant: KButtonVariant.outline,
              onPressed: () => _show(_EventTab.past),
            ),
          ),
        );
      case _EventTab.past:
        return _eventsSliver(
          ref.watch(eventsPastProvider),
          empty: KEmptyState(
            icon: KIcons.calendar,
            title: 'No past events',
            hint: 'Events at $branchLabel that have finished appear here.',
          ),
          capNote:
              'Showing the ${EventRepository.pastEventLimit} most recent '
              'events. Anything older is no longer listed.',
        );
      case _EventTab.rsvps:
        if (ref.watch(currentUserProvider).valueOrNull == null) {
          return _MessageSliver(
            child: KEmptyState(
              icon: KIcons.lock,
              title: 'Sign in to see your RSVPs',
              hint:
                  'Your RSVPs are saved to your account so they follow you '
                  'between devices.',
              action: KButton(
                label: 'Sign in',
                onPressed: () => context.push('/login'),
              ),
            ),
          );
        }
        return _rsvpSliver(ref.watch(myRsvpEventsProvider));
    }
  }

  /// [capNote] is shown under the list once it is full to the view cap, so a
  /// truncated archive never reads as the whole history.
  Widget _eventsSliver(
    AsyncValue<List<Event>> async, {
    required Widget empty,
    String? capNote,
  }) {
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const _LoadingSliver(),
      error: (_, _) => _MessageSliver(
        child: KErrorState(
          message: 'Events didn\u2019t load. Check your connection and retry.',
          onRetry: _refresh,
        ),
      ),
      data: (events) {
        if (events.isEmpty) return _MessageSliver(child: empty);
        final note = events.length >= EventRepository.pastEventLimit
            ? capNote
            : null;
        return _ListSliver(
          children: [
            for (final event in events) EventCard(event: event),
            if (note != null) _CapNote(text: note),
          ],
        );
      },
    );
  }

  /// "My RSVPs" is sectioned rather than flat: an RSVP'd event whose date has
  /// passed belongs under Past, never Upcoming. A group with no events
  /// contributes no header.
  ///
  /// The Past group is capped at [EventRepository.pastEventLimit] by
  /// [myRsvpEventsProvider]; when it is full, a closing note says so rather
  /// than letting a truncated list pass for the member's whole RSVP history.
  Widget _rsvpSliver(AsyncValue<RsvpEvents> async) {
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const _LoadingSliver(),
      error: (_, _) => _MessageSliver(
        child: KErrorState(
          message:
              'Your RSVPs didn\u2019t load. Check your connection and retry.',
          onRetry: _refresh,
        ),
      ),
      data: (grouped) {
        if (grouped.isEmpty) {
          return _MessageSliver(
            child: KEmptyState(
              icon: KIcons.check,
              title: 'No RSVPs yet',
              hint: 'Events you RSVP to will show up here.',
              action: KButton(
                label: 'See upcoming events',
                variant: KButtonVariant.outline,
                onPressed: () => _show(_EventTab.upcoming),
              ),
            ),
          );
        }
        return _ListSliver(
          children: [
            if (grouped.upcoming.isNotEmpty) ...[
              const _GroupHeader(title: 'Upcoming'),
              for (final event in grouped.upcoming) EventCard(event: event),
            ],
            if (grouped.past.isNotEmpty) ...[
              const _GroupHeader(title: 'Past'),
              for (final event in grouped.past) EventCard(event: event),
            ],
            if (grouped.past.length >= EventRepository.pastEventLimit)
              const _CapNote(
                text:
                    'Showing your ${EventRepository.pastEventLimit} most '
                    'recent past RSVPs.',
              ),
          ],
        );
      },
    );
  }
}

const EdgeInsets _listPadding = EdgeInsets.fromLTRB(
  KSpace.gutter,
  KSpace.x3,
  KSpace.gutter,
  KSize.contentBottomPad,
);

/// Event cards (and the headers and notes between them), [KSpace.lg] apart.
class _ListSliver extends StatelessWidget {
  const _ListSliver({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: _listPadding,
      sliver: SliverList.separated(
        itemCount: children.length,
        itemBuilder: (_, index) => children[index],
        separatorBuilder: (_, _) => const SizedBox(height: KSpace.lg),
      ),
    );
  }
}

/// An empty or error state, centred in the space under the tabs.
class _MessageSliver extends StatelessWidget {
  const _MessageSliver({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: child),
    );
  }
}

/// Blocks the size of event cards while the list loads.
class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver();

  static const int _cards = 3;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: _listPadding,
      sliver: SliverList.separated(
        itemCount: _cards,
        itemBuilder: (_, _) => const KSkeleton(
          height: KSize.dateBlockHeight + 2 * KSpace.xxl,
          radius: KRadius.card,
        ),
        separatorBuilder: (_, _) => const SizedBox(height: KSpace.lg),
      ),
    );
  }
}

/// "Upcoming" / "Past" above a group of RSVPs.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: KharisText.title.copyWith(color: context.k.text),
      ),
    );
  }
}

/// Closing line under a list that has been trimmed to a view cap. Quiet by
/// design: it explains an absence, it is not content.
class _CapNote extends StatelessWidget {
  const _CapNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: KharisText.caption.copyWith(color: context.k.muted),
    );
  }
}
