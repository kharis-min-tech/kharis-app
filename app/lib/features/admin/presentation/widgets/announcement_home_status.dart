import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/data/london_time.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';

/// Whether an announcement is on the app home screen right now, and for whom.
///
/// This mirrors the rules the home feed actually applies — it adds none of its
/// own. The carousel in `news_section.dart` watches `newsProvider(activeBranch)`,
/// which is served by `getAnnouncements` (`selectAnnouncements` in
/// `backend/functions/src/index.ts`), so an announcement is on the home screen
/// when:
///   1. `publishedAt` has passed (a scheduled item is not served yet),
///   2. `expiresAt` is unset or still in the future, and
///   3. its branch is the member's branch, or it is all-campus.
/// A blank or absent `branch` is all-campus, exactly as the API reads it.
///
/// The same derivation backs the Announcements tab of the web Content Studio
/// (`admin/index.html`, `homeVisibility`), so the two admin surfaces cannot
/// disagree with each other or with the app.
@immutable
class AnnouncementHomeVisibility {
  const AnnouncementHomeVisibility({
    required this.live,
    required this.audience,
    this.scheduledFor,
  });

  factory AnnouncementHomeVisibility.of(NewsItem item) =>
      AnnouncementHomeVisibility(
        live: item.isLive,
        audience: audienceFor(item.branch),
        scheduledFor: item.isScheduled ? item.publishedAt : null,
      );

  /// The label for an all-campus announcement, matching the branch dropdown.
  static const String allBranches = 'All Branches';

  /// Who an announcement scoped to [branch] reaches. Shared with the compose
  /// form so the preview and the published row can never disagree.
  static String audienceFor(String? branch) {
    final name = branch?.trim();
    return (name == null || name.isEmpty) ? allBranches : name;
  }

  /// True when members can see it on the home screen now.
  final bool live;

  /// The audience it reaches while live.
  final String audience;

  /// When a scheduled item goes live; `null` once published.
  final DateTime? scheduledFor;

  bool get scheduled => scheduledFor != null;

  String get label {
    final goesLive = scheduledFor;
    if (goesLive != null) {
      return 'Scheduled: goes live ${formatLondonDateTime(goesLive)}';
    }
    return live ? 'Live on home: $audience' : 'Expired: hidden from home';
  }
}

/// Per-row verdict on home-screen visibility. Deliberately the loudest thing
/// on the card: "is this actually showing?" is the question the admin has.
class AnnouncementHomeStatusChip extends StatelessWidget {
  const AnnouncementHomeStatusChip({super.key, required this.visibility});

  final AnnouncementHomeVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final live = visibility.live;
    final scheduled = visibility.scheduled;
    final tint = scheduled
        ? AppColors.secondary
        : (live ? AppColors.success : AppColors.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scheduled
                ? Icons.schedule_rounded
                : (live
                    ? Icons.smartphone_rounded
                    : Icons.visibility_off_rounded),
            size: 12,
            color: tint,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              visibility.label,
              style: AppTypography.labelMd.copyWith(
                color: tint,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// States the two rules that decide whether an announcement reaches the app
/// home screen, so the status on each row below it reads without guesswork.
class AnnouncementHomeRulesBanner extends StatelessWidget {
  const AnnouncementHomeRulesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.smartphone_rounded,
            size: 16,
            color: AppColors.secondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'These are the announcements in the carousel on the app home '
              'screen. A member sees one when it is set to their branch or to '
              '${AnnouncementHomeVisibility.allBranches}, its publish time has '
              'passed and it has not expired. Every row below says exactly '
              'where it stands.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells the admin, before they publish, exactly where the announcement lands
/// and who will see it. Reads the same [AnnouncementHomeVisibility] rules the
/// published rows use, so the promise here matches the verdict there.
class AnnouncementWillAppearPanel extends StatelessWidget {
  const AnnouncementWillAppearPanel({
    super.key,
    required this.audience,
    required this.expiresAt,
    required this.isNew,
    this.publishAt,
  });

  /// Already resolved through [AnnouncementHomeVisibility.audienceFor].
  final String audience;

  /// Expiry the save will write; `null` = never expires.
  final DateTime? expiresAt;

  /// Future go-live instant for a scheduled item; `null` = live on save.
  final DateTime? publishAt;

  /// A new announcement is pushed to its audience once it goes live (the
  /// `pushPendingAnnouncements` poller picks up a `publishedAt` that has just
  /// passed). An edit is not pushed again.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final expiry = expiresAt;
    final goesLive = publishAt;
    final expired = expiry != null && expiry.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.smartphone_rounded,
                size: 14,
                color: AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Where this shows',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _line(
            'In the announcements carousel on the app home screen, not in '
            'Events.',
          ),
          _line(
            audience == AnnouncementHomeVisibility.allBranches
                ? 'Seen by everyone, at every branch.'
                : 'Seen only by members whose campus is $audience.',
          ),
          if (goesLive != null)
            _line(
              'Hidden until ${formatLondonDateTime(goesLive)} UK time, then '
              'it goes live.',
            ),
          _line(
            expiry == null
                ? 'No expiry set, so it stays on the home screen until you '
                    'delete it.'
                : expired
                    ? 'Its expiry (${_formatFullDate(expiry)}) has already '
                        'passed, so it stays hidden on the home screen.'
                    : 'Drops off the home screen at the end of '
                        '${_formatFullDate(toLondonWallClock(expiry))} '
                        '(UK time).',
            tint: expired ? AppColors.error : null,
          ),
          if (isNew)
            _line(
              goesLive == null
                  ? 'That same audience also gets a push notification within '
                      'a few minutes of publishing.'
                  : 'That same audience also gets a push notification when '
                      'it goes live.',
            ),
        ],
      ),
    );
  }

  Widget _line(String text, {Color? tint}) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '• $text',
          style: AppTypography.bodySm.copyWith(
            color: tint ?? AppColors.onSurfaceVariant,
          ),
        ),
      );
}

/// `12 Mar 2026` — unambiguous, because an expiry date decides whether members
/// see the announcement at all.
String _formatFullDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

/// `Sat 4 Oct 2026, 09:00` on London's clock, for an instant.
String formatLondonDateTime(DateTime instant) =>
    DateFormat('EEE d MMM y, HH:mm').format(toLondonWallClock(instant));
