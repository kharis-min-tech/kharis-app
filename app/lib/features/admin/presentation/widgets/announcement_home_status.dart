import 'package:flutter/material.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';

/// Whether an announcement is on the app home screen right now, and for whom.
///
/// This mirrors the rules the home feed actually applies — it adds none of its
/// own. The carousel in `news_section.dart` watches `newsProvider(activeBranch)`,
/// which is served by `getAnnouncements` (`selectAnnouncements` in
/// `backend/functions/src/index.ts`), so an announcement is on the home screen
/// when:
///   1. `expiresAt` is unset or still in the future, and
///   2. its branch is the member's branch, or it is all-campus.
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
  });

  factory AnnouncementHomeVisibility.of(NewsItem item) =>
      AnnouncementHomeVisibility(
        live: !item.isExpired,
        audience: audienceFor(item.branch),
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

  String get label =>
      live ? 'Live on home — $audience' : 'Expired — hidden from home';
}

/// Per-row verdict on home-screen visibility. Deliberately the loudest thing
/// on the card: "is this actually showing?" is the question the admin has.
class AnnouncementHomeStatusChip extends StatelessWidget {
  const AnnouncementHomeStatusChip({super.key, required this.visibility});

  final AnnouncementHomeVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final live = visibility.live;
    final tint = live ? AppColors.success : AppColors.error;
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
            live ? Icons.smartphone_rounded : Icons.visibility_off_rounded,
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
              '${AnnouncementHomeVisibility.allBranches}, and it has not '
              'expired. Every row below says exactly where it stands.',
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
  });

  /// Already resolved through [AnnouncementHomeVisibility.audienceFor].
  final String audience;

  /// Expiry carried by the announcement being edited; `null` = never expires.
  /// Expiry itself is only editable in the web Content Studio.
  final DateTime? expiresAt;

  /// A new announcement is pushed to its audience shortly after publishing
  /// (`pushPendingAnnouncements` picks up a `publishedAt` inside the last 15
  /// minutes, which `addNews` always writes). An edit is not pushed again.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final expiry = expiresAt;
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
            'In the announcements carousel on the app home screen — not in '
            'Events.',
          ),
          _line(
            audience == AnnouncementHomeVisibility.allBranches
                ? 'Seen by everyone, at every branch.'
                : 'Seen only by members whose campus is $audience.',
          ),
          _line(
            expiry == null
                ? 'No expiry set, so it stays on the home screen until you '
                    'delete it. Expiry dates are set in the web Content Studio.'
                : expired
                    ? 'Its expiry (${_formatFullDate(expiry)}) has already '
                        'passed, so it stays hidden on the home screen.'
                    : 'Drops off the home screen at the start of '
                        '${_formatFullDate(expiry)}.',
            tint: expired ? AppColors.error : null,
          ),
          if (isNew)
            _line(
              'That same audience also gets a push notification within a few '
              'minutes of publishing.',
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
