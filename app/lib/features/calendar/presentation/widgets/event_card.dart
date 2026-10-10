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

/// Toast for event actions (RSVP, add to calendar). Plate colour, content
/// type, floating behaviour and shape all come from `snackBarTheme`; only the
/// bottom margin that clears the tab bar is surface-specific.
SnackBar eventToast(String message, {SnackBarAction? action}) => SnackBar(
  content: Text(message),
  action: action,
  duration: const Duration(milliseconds: 1900),
  margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
);

/// Where an event happens, for one-line display: the venue name, else its
/// street address, else the campus it belongs to. `null` when none is known.
String? eventPlaceLabel(Event event) {
  for (final candidate in [event.location, event.address, event.branch]) {
    final value = candidate?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Opens the event detail screen, handing over the loaded [event] so it
/// paints immediately. Pushed (never `go`) so Back returns to the caller.
void openEventDetail(BuildContext context, Event event) {
  context.push('/events/${Uri.encodeComponent(event.id)}', extra: event);
}

/// One event: photo banner with an overlaid date chip, title/time/location,
/// and a split RSVP | Add-to-calendar footer. The whole card opens the event
/// detail; the footer buttons keep their own actions.
///
/// The date chip is brand purple on a fixed light plate (6.7:1), and the
/// banner falls back to the deep brand purple when there is no photo. One
/// colour on purpose: a rotating rainbow carried no meaning, and its gold
/// step failed contrast on the plate.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = DateFormat('d').format(event.startTime);
    final month = DateFormat('MMM').format(event.startTime).toUpperCase();
    final weekday = DateFormat('EEE').format(event.startTime);
    final time = DateFormat('h:mm a').format(event.startTime);
    final whenText = '$weekday \u00b7 $time';
    final place = eventPlaceLabel(event);
    final isPast = event.isPastAt(DateTime.now());
    final isRsvped = ref.watch(isEventRsvpedProvider(event.id));

    // Shadow outside, ink inside: Material clips its children, so the shadow
    // has to live on a box around it to stay visible.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: context.kc.surface,
        borderRadius: AppRadius.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openEventDetail(context, event),
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
                    child: _DateChip(day: day, month: month),
                  ),
                  if (event.isFeatured)
                    const Positioned(
                      top: 11,
                      right: 11,
                      child: _FeaturedPill(),
                    ),
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
                    if (place != null) ...[
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
                                    : context.kc.onChip,
                                onTap: () =>
                                    toggleEventRsvp(context, ref, event),
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
                          onTap: () => addEventToCalendar(context, event),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner() {
    const fallback = ColoredBox(color: AppColors.primaryDeep);
    final url = event.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// Toggles the persisted RSVP for [event]. Button state comes from
/// [isEventRsvpedProvider], which is driven by the Firestore stream, so the
/// UI settles on the value that was actually written.
Future<void> toggleEventRsvp(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
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
      ..showSnackBar(
        eventToast(
          going
              ? 'You\u2019re going to ${event.title}.'
              : 'RSVP cancelled for ${event.title}.',
        ),
      );
  } on RsvpAuthRequiredException {
    _promptSignIn(messenger, router);
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        eventToast('Couldn\u2019t save your RSVP. Please try again.'),
      );
  }
}

void _promptSignIn(ScaffoldMessengerState messenger, GoRouter router) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      eventToast(
        'Sign in to RSVP to events.',
        action: SnackBarAction(
          label: 'Sign in',
          onPressed: () => router.push('/login'),
        ),
      ),
    );
}

/// Hands [event] to the device calendar. Events may legitimately have no end
/// time; a one-hour block is the sensible default for a calendar entry.
Future<void> addEventToCalendar(BuildContext context, Event event) async {
  final messenger = ScaffoldMessenger.of(context);
  final where = [
    event.location,
    event.address,
  ].map((s) => s?.trim() ?? '').where((s) => s.isNotEmpty).join(', ');
  final calEvent = add2cal.Event(
    title: event.title,
    description: event.description,
    location: where.isEmpty ? event.branch : where,
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

class _FeaturedPill extends StatelessWidget {
  const _FeaturedPill();

  @override
  Widget build(BuildContext context) {
    // 55% black over the brightest photo still gives white text 4.7:1.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        'Featured',
        style: AppTypography.ui(
          size: 10,
          weight: FontWeight.w700,
          letterSpacing: 0.3,
        ).copyWith(color: Colors.white),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.day, required this.month});

  final String day;
  final String month;
  static const Color color = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    // Fixed light plate in both themes: the chip sits on the photo banner,
    // so it keeps one plate and one ink whatever the active theme.
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
            style: AppTypography.ui(
              size: 18,
              weight: FontWeight.w700,
              height: 1,
            ).copyWith(color: color),
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
            style: AppTypography.ui(
              size: 12.5,
            ).copyWith(color: context.kc.muted),
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
      // 14 + 16 line + 14: a 44 px target across the half-width footer.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            label,
            style: AppTypography.ui(
              size: 13,
              weight: FontWeight.w700,
            ).copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
