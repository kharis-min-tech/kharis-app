import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/dismissed_notifications_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// What a feed row came from. Carries its own iconography and eyebrow label so
/// a member can tell an announcement from an event at a glance.
enum _NotifKind {
  announcement(Icons.campaign_rounded, 'Announcement'),
  event(Icons.event_rounded, 'Event');

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
  });

  /// [id] is namespaced by source so a news item and an event that happen to
  /// share a document id can never dismiss each other.
  factory _NotifItem.announcement(NewsItem n) => _NotifItem(
        id: 'news:${n.id}',
        kind: _NotifKind.announcement,
        title: n.title,
        body: n.body,
        date: n.publishedAt,
      );

  factory _NotifItem.event(Event e) => _NotifItem(
        id: 'event:${e.id}',
        kind: _NotifKind.event,
        title: e.title,
        body: e.description,
        date: e.startTime,
      );

  final String id;
  final _NotifKind kind;
  final String title;
  final String? body;
  final DateTime date;
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

/// Merges announcements and upcoming events into one feed, drops rows the
/// member has dismissed, and pins reminders on top.
///
/// Upcoming events are reminders — things a member can still act on — so they
/// outrank announcements, which are informational and already published. A
/// service starting tomorrow must not sit under this morning's news post.
/// Within the reminder block the soonest event leads; within announcements
/// the freshest post leads.
List<_NotifItem> _buildFeed({
  required List<NewsItem> news,
  required List<Event> events,
  required Set<String> dismissed,
  required DateTime now,
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
        : b.date.compareTo(a.date); // freshest announcement first
  });
  return items;
}

/// Shows real announcements and upcoming events as a unified, dismissible
/// notification feed. Both sources are already scoped to the active branch by
/// their providers, all-campus content included.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentBranchProvider).valueOrNull;
    final newsAsync = ref.watch(newsProvider(branch));
    final eventsAsync = ref.watch(upcomingEventsProvider(branch));
    final dismissed = ref.watch(dismissedNotificationsProvider);

    final loading = newsAsync.isLoading || eventsAsync.isLoading;
    final items = loading
        ? const <_NotifItem>[]
        : _buildFeed(
            news: newsAsync.valueOrNull ?? const [],
            events: eventsAsync.valueOrNull ?? const [],
            dismissed: dismissed,
            now: DateTime.now(),
          );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: AppTypography.titleMd.copyWith(color: context.kc.onBg),
        ),
        iconTheme: IconThemeData(color: context.kc.onBg),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _clearAll(context, ref, items),
              child: Text(
                'Clear all',
                style:
                    AppTypography.labelMd.copyWith(color: context.kc.accentInk),
              ),
            ),
        ],
      ),
      body: _body(
        context,
        ref,
        loading: loading,
        failed: !newsAsync.hasValue &&
            !eventsAsync.hasValue &&
            (newsAsync.hasError || eventsAsync.hasError),
        items: items,
        hasDismissed: dismissed.isNotEmpty,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required bool loading,
    required bool failed,
    required List<_NotifItem> items,
    required bool hasDismissed,
  }) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (failed) {
      return const _Empty(
        icon: Icons.wifi_off_rounded,
        title: 'Unable to load notifications',
        subtitle: 'Please check your connection and try again.',
      );
    }
    if (items.isEmpty) {
      return _Empty(
        icon: hasDismissed
            ? Icons.mark_email_read_outlined
            : Icons.notifications_none_rounded,
        title:
            hasDismissed ? 'You\u2019re all caught up' : 'No notifications yet',
        subtitle: hasDismissed
            ? 'Dismissed notifications stay hidden on this device.'
            : 'Announcements and upcoming events will show up here.',
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
        return Dismissible(
          key: ValueKey(item.id),
          background: const _SwipePlate(alignment: Alignment.centerLeft),
          secondaryBackground:
              const _SwipePlate(alignment: Alignment.centerRight),
          onDismissed: (_) => _dismiss(context, ref, item),
          child: _NotifRow(item: item),
        );
      },
    );
  }

  void _dismiss(BuildContext context, WidgetRef ref, _NotifItem item) {
    final controller = ref.read(dismissedNotificationsProvider.notifier);
    controller.dismiss(item.id);
    _showUndo(
      context,
      'Notification dismissed.',
      () => controller.restore([item.id]),
    );
  }

  void _clearAll(BuildContext context, WidgetRef ref, List<_NotifItem> items) {
    final ids = items.map((i) => i.id).toList(growable: false);
    final controller = ref.read(dismissedNotificationsProvider.notifier);
    controller.dismissAll(ids);
    _showUndo(
      context,
      ids.length == 1
          ? 'Notification cleared.'
          : '${ids.length} notifications cleared.',
      () => controller.restore(ids),
    );
  }

  /// Toast styling comes from `snackBarTheme`; this route overlays the shell,
  /// so there is no tab bar to clear and the default margin is correct.
  void _showUndo(BuildContext context, String message, VoidCallback onUndo) {
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

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.item});

  final _NotifItem item;

  @override
  Widget build(BuildContext context) {
    final body = item.body;
    return Container(
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
            child: Icon(item.kind.icon, color: context.kc.accentInk, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.kind.label} \u00b7 '
                  '${_relativeLabel(item.date, DateTime.now())}',
                  style:
                      AppTypography.labelMd.copyWith(color: context.kc.muted),
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
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style:
                        AppTypography.bodySm.copyWith(color: context.kc.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The plate revealed behind a row mid-swipe.
class _SwipePlate extends StatelessWidget {
  const _SwipePlate({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.danger,
      child: Align(
        alignment: alignment,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child:
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Empty / error state ───────────────────────────────────────────────────────

@immutable
class _EmptyAction {
  const _EmptyAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

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
    return Center(
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
              style: AppTypography.bodySm.copyWith(color: context.kc.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: action.onPressed,
                child: Text(
                  action.label,
                  style: AppTypography.labelMd
                      .copyWith(color: context.kc.accentInk),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
