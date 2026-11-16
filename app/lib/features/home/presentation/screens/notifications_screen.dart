import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/announcement_detail.dart';
import 'package:kharis_app/shared/providers/dismissed_notifications_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/widgets/notification_permission_card.dart';
import 'package:kharis_app/ui/components/components.dart';

/// What a feed row came from. Carries its own icon and label so a member can
/// tell an announcement from an event at a glance.
enum _NotifKind {
  announcement(KIcons.bell, 'Announcement'),
  event(KIcons.calendar, 'Event');

  const _NotifKind(this.icon, this.label);

  final String icon;
  final String label;
}

/// A single row in the unified notification feed.
@immutable
class _NotifItem {
  const _NotifItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    this.body,
    this.event,
    this.news,
  });

  /// [id] is namespaced by source so a news item and an event that happen to
  /// share a document id can never dismiss each other.
  factory _NotifItem.announcement(NewsItem n) => _NotifItem(
    id: announcementNotificationId(n.id),
    kind: _NotifKind.announcement,
    title: n.title,
    body: n.body,
    date: n.publishedAt,
    news: n,
  );

  factory _NotifItem.event(Event e) => _NotifItem(
    id: eventNotificationId(e.id),
    kind: _NotifKind.event,
    title: e.title,
    body: e.description,
    date: e.startTime,
    event: e,
  );

  final String id;
  final _NotifKind kind;
  final String title;
  final String? body;
  final DateTime date;

  /// Source event when [kind] is [_NotifKind.event].
  final Event? event;

  /// Source announcement when [kind] is [_NotifKind.announcement].
  final NewsItem? news;

  /// Whether tapping the row opens anything.
  bool get opens => event != null || news != null;
}

/// The heading of a day's group: "Today", "Tomorrow", "Yesterday", else
/// "Sun 15 Nov" (with the year when it is not this one).
String _dayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(day.year, day.month, day.day).difference(today).inDays;
  return switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => DateFormat(
      day.year == now.year ? 'EEE d MMM' : 'EEE d MMM y',
    ).format(day),
  };
}

/// Merges announcements and upcoming events into one
/// feed, drops rows the member has dismissed, and pins reminders on top.
///
/// Upcoming events are reminders — things a member can still act on — so they
/// outrank announcements, which are informational and already out. A service
/// starting tomorrow must not sit under this morning's news post. Within the
/// reminder block the soonest event leads; below it the newest announcement
/// leads.
List<_NotifItem> _buildFeed({
  required List<NewsItem> news,
  required List<Event> events,
  required Set<String> dismissed,
}) {
  final items = <_NotifItem>[
    for (final n in news) _NotifItem.announcement(n),
    for (final e in events) _NotifItem.event(e),
  ]..removeWhere((i) => dismissed.contains(i.id));
  int rank(_NotifItem i) => i.kind == _NotifKind.event ? 0 : 1;
  items.sort((a, b) {
    final byKind = rank(a).compareTo(rank(b));
    if (byKind != 0) return byKind;
    return a.kind == _NotifKind.event
        ? a.date.compareTo(b.date) // soonest reminder first
        : b.date.compareTo(a.date); // newest announcement first
  });
  return items;
}

/// [items] grouped by calendar day, days in order of first appearance and
/// rows in feed order within each day.
List<(DateTime, List<_NotifItem>)> _groupByDay(List<_NotifItem> items) {
  final groups = <DateTime, List<_NotifItem>>{};
  for (final item in items) {
    final d = item.date;
    groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(item);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

/// The member's notification feed, or (via [NotificationsScreen.announcements])
/// the full announcements list behind Home's "See all".
///
/// News and events are scoped to the member's campus plus all-campus content
/// by [campusNewsProvider] / [campusUpcomingEventsProvider]. Rows open what
/// they are about: an event row (or an announcement promoting an event) opens
/// the event; a plain announcement opens its full text and call-to-action.
class NotificationsScreen extends ConsumerStatefulWidget {
  /// Unified feed: upcoming events and announcements, dismissible.
  const NotificationsScreen({super.key})
    : announcementsOnly = false,
      focusId = null;

  /// Every live announcement for the member's campus, newest first. Not
  /// dismissible: this is the archive, not an inbox. [focusId] (a `news` doc
  /// id, from a push) opens that announcement as soon as it has loaded.
  const NotificationsScreen.announcements({super.key, this.focusId})
    : announcementsOnly = true;

  final bool announcementsOnly;
  final String? focusId;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _focusHandled = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final newsAsync = ref.watch(campusNewsProvider);
    final eventsAsync = widget.announcementsOnly
        ? const AsyncData<List<Event>>([])
        : ref.watch(campusUpcomingEventsProvider);
    final dismissed = widget.announcementsOnly
        ? const <String>{}
        : ref.watch(dismissedNotificationsProvider);

    _maybeOpenFocused(newsAsync);

    final loading =
        (newsAsync.isLoading && !newsAsync.hasValue) ||
        (eventsAsync.isLoading && !eventsAsync.hasValue);
    final failed =
        !loading &&
        !newsAsync.hasValue &&
        !eventsAsync.hasValue &&
        (newsAsync.hasError || eventsAsync.hasError);
    final items = loading
        ? const <_NotifItem>[]
        : _buildFeed(
            news: newsAsync.valueOrNull ?? const [],
            events: eventsAsync.valueOrNull ?? const [],
            dismissed: dismissed,
          );
    // An empty inbox on a device that blocks pushes reads as "nothing will
    // ever come", so say what the member would get and how to turn it on,
    // until they turn it on or say "Not now".
    final permission = widget.announcementsOnly
        ? null
        : ref.watch(notificationPermissionProvider).valueOrNull;
    final offerPermission =
        (permission == NotificationPermission.askable ||
            permission == NotificationPermission.blocked) &&
        !ref.watch(notificationPromptDeclinedProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Opened with nothing beneath it (a push or a deep link),
                // system back goes Home rather than leaving the app.
                PopScope(
                  canPop: GoRouter.maybeOf(context)?.canPop() ?? true,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) GoRouter.of(context).go('/home');
                  },
                  child: const SizedBox(height: KSpace.md),
                ),
                KScreenHeader(
                  title: widget.announcementsOnly
                      ? 'Announcements'
                      : 'Notifications',
                  actions: [
                    if (!widget.announcementsOnly)
                      KIconButton(
                        key: const Key('notification-settings-button'),
                        icon: KIcons.gear,
                        label: 'Notification settings',
                        onPressed: _openPreferences,
                      ),
                  ],
                ),
                if (!widget.announcementsOnly && items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpace.gutter,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: KTextLink(
                        label: 'Clear all',
                        onTap: () => _clearAll(items),
                      ),
                    ),
                  ),
                if (offerPermission)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.md,
                      KSpace.gutter,
                      KSpace.md,
                    ),
                    child: NotificationPermissionCard(
                      permission: permission!,
                      message:
                          'Get a reminder before your branch\u2019s service, '
                          'event updates, the daily Bible reading and church '
                          'announcements. You choose which ones.',
                      onPreferences: _openPreferences,
                      onNotNow: () => ref
                          .read(notificationPromptDeclinedProvider.notifier)
                          .decline(),
                    ),
                  ),
                Expanded(
                  child: loading
                      ? _FeedSkeleton(cards: widget.announcementsOnly)
                      : RefreshIndicator(
                          color: k.primaryText,
                          backgroundColor: k.surface,
                          onRefresh: () => refreshCampusContent(ref),
                          child: _body(
                            failed: failed,
                            items: items,
                            hasDismissed: dismissed.isNotEmpty,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Notification preferences: what this member can choose to receive.
  void _openPreferences() => unawaited(context.push('/settings/notifications'));

  /// Opens the pushed announcement once, after the feed that contains it has
  /// loaded. An id the feed does not hold (expired, other campus) just leaves
  /// the member on the list.
  ///
  /// A push invalidates the feed before opening this screen, and while that
  /// refetch runs the value is still the previous list, which does not hold
  /// the new item. Only a settled value is searched.
  void _maybeOpenFocused(AsyncValue<List<NewsItem>> newsAsync) {
    final id = widget.focusId;
    if (_focusHandled || id == null) return;
    final news = newsAsync.valueOrNull;
    if (newsAsync.isLoading || news == null) return;
    _focusHandled = true;
    final match = news.where((n) => n.id == id).firstOrNull;
    if (match == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openAnnouncement(context, match));
    });
  }

  Widget _body({
    required bool failed,
    required List<_NotifItem> items,
    required bool hasDismissed,
  }) {
    if (failed) {
      return _Centered(
        child: KErrorState(
          message: widget.announcementsOnly
              ? 'Announcements didn\u2019t load. Check your connection and '
                    'retry.'
              : 'Notifications didn\u2019t load. Check your connection and '
                    'retry.',
          onRetry: () => refreshCampusContent(ref),
        ),
      );
    }
    if (items.isEmpty) {
      if (widget.announcementsOnly) {
        return const _Centered(
          child: KEmptyState(
            icon: KIcons.bell,
            title: 'No announcements right now',
            hint: 'News from your branch will show up here.',
          ),
        );
      }
      return _Centered(
        child: KEmptyState(
          icon: hasDismissed ? KIcons.check : KIcons.bell,
          title: hasDismissed
              ? 'You\u2019re all caught up'
              : 'No notifications yet',
          hint: hasDismissed
              ? 'Dismissed notifications stay hidden on this device.'
              : 'Announcements, church notifications and upcoming events '
                    'will show up here.',
          action: hasDismissed
              ? KButton(
                  label: 'Restore dismissed',
                  variant: KButtonVariant.outline,
                  onPressed: () => ref
                      .read(dismissedNotificationsProvider.notifier)
                      .restoreAll(),
                )
              : null,
        ),
      );
    }

    final bottom =
        KSize.contentBottomPad + MediaQuery.paddingOf(context).bottom;

    if (widget.announcementsOnly) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          KSpace.gutter,
          KSpace.xl,
          KSpace.gutter,
          bottom,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: KSpace.xl),
        itemBuilder: (context, index) {
          final item = items[index];
          final body = item.body?.trim();
          final linked = item.news?.eventId?.trim();
          return KAnnouncementCard(
            month: DateFormat('MMM').format(item.date),
            day: DateFormat('d').format(item.date),
            dateSemanticLabel: DateFormat('EEE d MMM').format(item.date),
            title: item.title,
            snippet: body == null || body.isEmpty ? null : body,
            actionLabel: linked != null && linked.isNotEmpty
                ? 'View event'
                : 'Read more',
            onTap: item.opens ? () => _open(item) : null,
          );
        },
      );
    }

    final now = DateTime.now();
    final groups = _groupByDay(items);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        KSpace.gutter,
        KSpace.md,
        KSpace.gutter,
        bottom,
      ),
      children: [
        for (final (i, (day, rows)) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: KSpace.gutter),
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.md),
            child: Semantics(
              header: true,
              child: Text(
                _dayLabel(day, now),
                style: KharisText.caption.copyWith(color: context.k.muted),
              ),
            ),
          ),
          KListGroup(
            children: [
              for (final item in rows)
                Dismissible(
                  key: ValueKey(item.id),
                  background: const _SwipePlate(
                    alignment: Alignment.centerLeft,
                  ),
                  secondaryBackground: const _SwipePlate(
                    alignment: Alignment.centerRight,
                  ),
                  onDismissed: (_) => _dismiss(item),
                  child: _NotifRow(
                    item: item,
                    onTap: item.opens ? () => _open(item) : null,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _open(_NotifItem item) {
    final event = item.event;
    if (event != null) {
      openEventDetail(context, event);
      return;
    }
    final news = item.news;
    if (news != null) {
      unawaited(openAnnouncement(context, news));
    }
  }

  void _dismiss(_NotifItem item) {
    final controller = ref.read(dismissedNotificationsProvider.notifier);
    controller.dismiss(item.id);
    _showUndo('Notification dismissed.', () => controller.restore([item.id]));
  }

  void _clearAll(List<_NotifItem> items) {
    final ids = items.map((i) => i.id).toList(growable: false);
    final controller = ref.read(dismissedNotificationsProvider.notifier);
    controller.dismissAll(ids);
    _showUndo(
      ids.length == 1
          ? 'Notification cleared.'
          : '${ids.length} notifications cleared.',
      () => controller.restore(ids),
    );
  }

  /// This route overlays the shell, so there is no tab bar to clear and the
  /// default margin is correct.
  void _showUndo(String message, VoidCallback onUndo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'Undo', onPressed: onUndo),
        ),
      );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────

class _NotifRow extends ConsumerWidget {
  const _NotifRow({required this.item, this.onTap});

  final _NotifItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = item.body?.trim();
    final linkedId = item.news?.eventId;
    final event =
        item.event ??
        (linkedId == null ? null : ref.watch(linkedEventProvider(linkedId)));
    final venue = event == null ? null : eventVenueLine(event);
    final meta = [
      item.kind.label,
      if (item.kind == _NotifKind.event) DateFormat('HH:mm').format(item.date),
      ?venue,
      if (venue == null && body != null && body.isNotEmpty) body,
    ].join(' \u00b7 ');
    // Opaque so the swipe plate stays behind the row rather than showing
    // through it.
    return ColoredBox(
      color: context.k.surface,
      child: KListRow(
        leading: KIconTile(item.kind.icon),
        title: item.title,
        meta: meta,
        showChevron: onTap != null,
        onTap: onTap,
      ),
    );
  }
}

/// The plate revealed behind a row mid-swipe. Swiping hides the row on this
/// device; nothing is deleted, so it says "Hide", not "Delete".
class _SwipePlate extends StatelessWidget {
  const _SwipePlate({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ColoredBox(
      color: k.surface2,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          child: ExcludeSemantics(
            child: Text(
              'Hide',
              style: KharisText.link.copyWith(color: k.muted),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading / empty / error state ─────────────────────────────────────────────

/// Blocks standing in for the feed while it loads: one grouped list of rows
/// for the inbox, or cards for the announcements list.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.cards});

  final bool cards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('notifications-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        KSpace.gutter,
        KSpace.xl,
        KSpace.gutter,
        0,
      ),
      children: [
        if (cards)
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: KSpace.xl),
            const KSkeleton(height: KSize.dateBlockHeight + 2 * KSpace.xxl),
          ]
        else ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: KSkeleton(width: KSize.dateBlockWidth, height: KSpace.xxl),
          ),
          const SizedBox(height: KSpace.md),
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(height: KSpace.xxs),
            const KSkeleton(height: KSize.listRow),
          ],
        ],
      ],
    );
  }
}

/// Centres an empty or error message. Scrollable (always) so pull-to-refresh
/// works on it.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
