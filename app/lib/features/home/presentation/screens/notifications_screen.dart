import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/data/studio_notification_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/announcement_detail.dart';
import 'package:kharis_app/shared/providers/dismissed_notifications_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a feed row came from. Carries its own iconography and eyebrow label so
/// a member can tell an announcement from an event at a glance.
enum _NotifKind {
  announcement(Icons.campaign_rounded, 'Announcement'),
  event(Icons.event_rounded, 'Event'),
  studio(Icons.notifications_rounded, 'Notification');

  const _NotifKind(this.icon, this.label);

  final IconData icon;
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
    this.link,
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

  /// A push sent from Content Studio, dated when it went out.
  factory _NotifItem.studio(StudioNotification n) => _NotifItem(
    id: studioNotificationId(n.id),
    kind: _NotifKind.studio,
    title: n.title,
    body: n.body,
    date: n.sentAt ?? n.sendAt ?? n.createdAt ?? DateTime.now(),
    link: n.link,
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

  /// Where a [_NotifKind.studio] row opens: an app path or a web address.
  final String? link;

  /// Whether tapping the row opens anything.
  bool get opens => event != null || news != null || link != null;
}

/// Sign-aware relative label.
///
/// The feed mixes announcements (published in the past) with events (starting
/// in the future), so a formatter that assumes the past renders a future
/// instant as a negative magnitude — "-36225m ago" for an event three weeks
/// out. Direction is read off the sign and the magnitude is always positive:
/// past reads "3h ago", future reads "in 3h", and anything more than a week
/// either way falls back to an absolute date, which is clearer than "in 25d".
String _relativeLabel(DateTime dt, DateTime now) {
  final diff = dt.difference(now);
  final magnitude = diff.abs();
  if (magnitude.inDays >= 7) {
    return DateFormat(dt.year == now.year ? 'MMM d' : 'MMM d, y').format(dt);
  }
  if (magnitude.inMinutes < 1) return 'Now';
  final amount = magnitude.inMinutes < 60
      ? '${magnitude.inMinutes}m'
      : magnitude.inHours < 24
      ? '${magnitude.inHours}h'
      : '${magnitude.inDays}d';
  return diff.isNegative ? '$amount ago' : 'in $amount';
}

/// Merges announcements, Studio notifications and upcoming events into one
/// feed, drops rows the member has dismissed, and pins reminders on top.
///
/// Upcoming events are reminders — things a member can still act on — so they
/// outrank announcements and notifications, which are informational and
/// already out. A service starting tomorrow must not sit under this morning's
/// news post. Within the reminder block the soonest event leads; below it the
/// newest announcement or notification leads.
List<_NotifItem> _buildFeed({
  required List<NewsItem> news,
  required List<Event> events,
  required List<StudioNotification> studio,
  required Set<String> dismissed,
}) {
  final items = <_NotifItem>[
    for (final n in news) _NotifItem.announcement(n),
    for (final e in events) _NotifItem.event(e),
    for (final n in studio) _NotifItem.studio(n),
  ]..removeWhere((i) => dismissed.contains(i.id));
  int rank(_NotifItem i) => i.kind == _NotifKind.event ? 0 : 1;
  items.sort((a, b) {
    final byKind = rank(a).compareTo(rank(b));
    if (byKind != 0) return byKind;
    return a.kind == _NotifKind.event
        ? a.date.compareTo(b.date) // soonest reminder first
        : b.date.compareTo(a.date); // newest announcement/notification first
  });
  return items;
}

/// The member's notification feed, or (via [NotificationsScreen.announcements])
/// the full announcements list behind Home's "See all".
///
/// News and events are scoped to the member's campus plus all-campus content
/// by [campusNewsProvider] / [campusUpcomingEventsProvider]; Studio
/// notifications (sent to everyone or the member's branch) come from
/// [inboxNotificationsProvider]. Rows open what they are about: an event row
/// (or an announcement promoting an event) opens the event; a plain
/// announcement opens its full text and call-to-action; a notification opens
/// its link.
class NotificationsScreen extends ConsumerStatefulWidget {
  /// Unified feed: upcoming events, announcements and Studio notifications,
  /// dismissible.
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
    final newsAsync = ref.watch(campusNewsProvider);
    final eventsAsync = widget.announcementsOnly
        ? const AsyncData<List<Event>>([])
        : ref.watch(campusUpcomingEventsProvider);
    final studioAsync = widget.announcementsOnly
        ? const AsyncData<List<StudioNotification>>([])
        : ref.watch(inboxNotificationsProvider);
    final dismissed = widget.announcementsOnly
        ? const <String>{}
        : ref.watch(dismissedNotificationsProvider);

    _maybeOpenFocused(newsAsync);

    // Studio notifications never hold the feed back: they join it when their
    // query answers, and a failed query just leaves them out.
    final loading =
        (newsAsync.isLoading && !newsAsync.hasValue) ||
        (eventsAsync.isLoading && !eventsAsync.hasValue);
    final studio = studioAsync.valueOrNull ?? const <StudioNotification>[];
    final failed =
        !loading &&
        !newsAsync.hasValue &&
        !eventsAsync.hasValue &&
        studio.isEmpty &&
        (newsAsync.hasError || eventsAsync.hasError);
    final items = loading
        ? const <_NotifItem>[]
        : _buildFeed(
            news: newsAsync.valueOrNull ?? const [],
            events: eventsAsync.valueOrNull ?? const [],
            studio: studio,
            dismissed: dismissed,
          );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, color: context.kc.onBg),
          onPressed: () {
            final router = GoRouter.of(context);
            router.canPop() ? router.pop() : router.go('/home');
          },
        ),
        title: Text(
          widget.announcementsOnly ? 'Announcements' : 'Notifications',
          style: AppTypography.titleMd.copyWith(color: context.kc.onBg),
        ),
        iconTheme: IconThemeData(color: context.kc.onBg),
        actions: [
          if (!widget.announcementsOnly && items.isNotEmpty)
            TextButton(
              onPressed: () => _clearAll(items),
              child: Text(
                'Clear all',
                style: AppTypography.labelMd.copyWith(
                  color: context.kc.accentInk,
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const _FeedSkeleton()
          : RefreshIndicator(
              color: context.kc.accentInk,
              backgroundColor: context.kc.surface,
              onRefresh: () => refreshCampusContent(ref),
              child: _body(
                failed: failed,
                items: items,
                hasDismissed: dismissed.isNotEmpty,
              ),
            ),
    );
  }

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
      return _Empty(
        icon: Icons.wifi_off_rounded,
        title: widget.announcementsOnly
            ? 'Unable to load announcements'
            : 'Unable to load notifications',
        subtitle: 'Please check your connection and try again.',
        action: _EmptyAction(
          label: 'Retry',
          onPressed: () => refreshCampusContent(ref),
        ),
      );
    }
    if (items.isEmpty) {
      if (widget.announcementsOnly) {
        return const _Empty(
          icon: Icons.campaign_outlined,
          title: 'No announcements right now',
          subtitle: 'News from your branch will show up here.',
        );
      }
      return _Empty(
        icon: hasDismissed
            ? Icons.mark_email_read_outlined
            : Icons.notifications_none_rounded,
        title: hasDismissed
            ? 'You\u2019re all caught up'
            : 'No notifications yet',
        subtitle: hasDismissed
            ? 'Dismissed notifications stay hidden on this device.'
            : 'Announcements, church notifications and upcoming events '
                  'will show up here.',
        action: hasDismissed
            ? _EmptyAction(
                label: 'Restore dismissed',
                onPressed: () => ref
                    .read(dismissedNotificationsProvider.notifier)
                    .restoreAll(),
              )
            : null,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(
        color: context.kc.divider,
        height: 1,
        indent: 20,
        endIndent: 20,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final row = _NotifRow(
          item: item,
          onTap: item.opens ? () => _open(item) : null,
        );
        if (widget.announcementsOnly) return row;
        return Dismissible(
          key: ValueKey(item.id),
          background: const _SwipePlate(alignment: Alignment.centerLeft),
          secondaryBackground: const _SwipePlate(
            alignment: Alignment.centerRight,
          ),
          onDismissed: (_) => _dismiss(item),
          child: row,
        );
      },
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
      return;
    }
    final link = item.link;
    if (link != null) _openLink(link);
  }

  /// A notification's link: app paths open above this feed (tab roots are
  /// switched to), web addresses in the browser.
  void _openLink(String link) {
    final target = notificationLinkTarget(link);
    if (target != null) {
      final router = GoRouter.of(context);
      target.overlay
          ? router.push(target.location)
          : router.go(target.location);
      return;
    }
    final uri = externalNotificationUri(link);
    if (uri == null) return;
    unawaited(
      launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).catchError((Object _) => false),
    );
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

  /// Toast styling comes from `snackBarTheme`; this route overlays the shell,
  /// so there is no tab bar to clear and the default margin is correct.
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
    final body = item.body;
    final linkedId = item.news?.eventId;
    final event =
        item.event ??
        (linkedId == null ? null : ref.watch(linkedEventProvider(linkedId)));
    final venue = event == null ? null : eventVenueLine(event);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Opaque so the swipe plate stays behind the row rather than bleeding
        // through it.
        color: context.kc.bg,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.kc.chipBg,
              ),
              child: Icon(
                item.kind.icon,
                color: context.kc.accentInk,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.kind.label} \u00b7 '
                    '${_relativeLabel(item.date, DateTime.now())}',
                    style: AppTypography.labelMd.copyWith(
                      color: context.kc.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.title,
                    style: AppTypography.bodyLg.copyWith(
                      color: context.kc.onBg,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (venue != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: context.kc.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            venue,
                            style: AppTypography.bodySm.copyWith(
                              color: context.kc.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: AppTypography.bodySm.copyWith(
                        color: context.kc.muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.kc.faint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The plate revealed behind a row mid-swipe. Swiping hides the row on this
/// device; nothing is deleted, so the icon says "hide", not "trash".
class _SwipePlate extends StatelessWidget {
  const _SwipePlate({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.kc.surfaceMuted,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Icon(
            Icons.visibility_off_outlined,
            color: context.kc.muted,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ── Loading / empty / error state ─────────────────────────────────────────────

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('notifications-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 40, height: 40, radius: 20),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 110, height: 11),
                  SizedBox(height: 8),
                  SkeletonLine(width: 220),
                  SizedBox(height: 6),
                  SkeletonLine(width: 160, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _EmptyAction {
  const _EmptyAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Empty/error message. Scrollable (always) so pull-to-refresh works on it.
class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _EmptyAction? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: context.kc.muted, size: 44),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: AppTypography.bodyLg.copyWith(
                      color: context.kc.onBg,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: context.kc.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: action.onPressed,
                      child: Text(
                        action.label,
                        style: AppTypography.labelMd.copyWith(
                          color: context.kc.accentInk,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
