import 'package:add_2_calendar_new/add_2_calendar_new.dart' as add2cal;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Toast for the Events surface. Plate colour, content type, floating
/// behaviour and shape all come from `snackBarTheme`; only the bottom margin
/// that clears the tab bar is surface-specific. Shared with
/// `calendar_screen.dart` so every Events toast sits at the same height.
SnackBar eventToast(String message, {SnackBarAction? action}) => SnackBar(
      content: Text(message),
      action: action,
      duration: const Duration(milliseconds: 1900),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
    );

/// One event: photo banner with an overlaid date chip, title/time/location,
/// and a split RSVP | Add-to-calendar footer.
///
/// [accent] tints the date chip and the fallback banner gradient; the caller
/// cycles a palette so no two adjacent cards match.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, required this.accent});

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
        ..showSnackBar(eventToast(going
            ? 'You\u2019re going to ${event.title} \ud83c\udf89'
            : 'RSVP cancelled for ${event.title}.'));
    } on RsvpAuthRequiredException {
      _promptSignIn(messenger, router);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            eventToast('Couldn\u2019t save your RSVP. Please try again.'));
    }
  }

  void _promptSignIn(ScaffoldMessengerState messenger, GoRouter router) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(eventToast(
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
        ..showSnackBar(eventToast('Couldn\u2019t open your calendar.'));
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
    // the accent palette it carries is calibrated for a light plate over
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
