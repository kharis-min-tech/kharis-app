import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// Internal unified notification item for display.
class _NotifItem {
  const _NotifItem({
    required this.icon,
    required this.title,
    this.body,
    required this.date,
  });

  final IconData icon;
  final String title;
  final String? body;
  final DateTime date;
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

/// Shows recent announcements and upcoming events as a unified notification
/// feed, sorted newest/soonest first.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final newsAsync = ref.watch(newsProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider(null));

    final userBranch = userAsync.valueOrNull?.branch;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      body: Builder(
        builder: (context) {
          if (newsAsync.isLoading || eventsAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final newsItems = newsAsync.valueOrNull ?? [];
          final events = eventsAsync.valueOrNull ?? [];

          final items = <_NotifItem>[];

          // Announcements - church-wide (null branch) or matching user branch.
          for (final n in newsItems) {
            if (n.branch == null || n.branch == userBranch) {
              items.add(
                _NotifItem(
                  icon: Icons.campaign_rounded,
                  title: n.title,
                  body: n.body,
                  date: n.publishedAt,
                ),
              );
            }
          }

          // Events - church-wide or matching user branch.
          for (final e in events) {
            if (e.branch == null || e.branch == userBranch) {
              items.add(
                _NotifItem(
                  icon: Icons.event_rounded,
                  title: e.title,
                  body: e.description,
                  date: e.startTime,
                ),
              );
            }
          }

          // Sort newest first.
          items.sort((a, b) => b.date.compareTo(a.date));

          if (items.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const Divider(color: Color(0x14000000), height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceSubtle,
                  ),
                  child: Icon(item.icon, color: AppColors.secondary, size: 20),
                ),
                title: Text(
                  item.title,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: item.body != null
                    ? Text(
                        item.body!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Text(
                  _timeAgo(item.date),
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
