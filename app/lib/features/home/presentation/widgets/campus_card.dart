import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart'
    show directionsUri;
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

/// When [service] meets, e.g. `Sundays · 10:00 AM – 12:00 PM`; null when the
/// Studio set neither a day nor a time.
@visibleForTesting
String? campusServiceWhen(CampusService service) {
  final start = formatServiceTime(service.startTime);
  final end = formatServiceTime(service.endTime);
  final time = start == null
      ? end
      : end == null
      ? start
      : '$start \u2013 $end';
  final parts = [?service.day, ?time];
  return parts.isEmpty ? null : parts.join(' \u00b7 ');
}

/// A tappable Instagram link from what the Studio stored: a full URL, or a
/// handle with or without `@`.
@visibleForTesting
Uri? instagramUri(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
    return Uri.tryParse(value);
  }
  final handle = value.replaceFirst(RegExp(r'^@'), '');
  if (handle.isEmpty) return null;
  return Uri.https('www.instagram.com', '/$handle/');
}

/// "Your campus" card: when and where the member's campus meets, and how
/// to reach it.
///
/// Reads the Studio's structured [Branch.services] (each with its venue and
/// directions) and [Branch.contact] (call, email, Instagram). A campus with
/// no services yet falls back to the legacy [Branch.meetingDays] /
/// [Branch.meetingTime] / [Branch.address] mirrors.
///
/// Renders nothing when no campus is selected (all-campus view) or the
/// campus has nothing to show, rather than an empty card.
class CampusCard extends ConsumerWidget {
  const CampusCard({super.key, this.padding = EdgeInsets.zero});

  /// Outer padding, applied only when the card renders, so Home's spacing
  /// collapses with it.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentCampusProvider);
    if (branch == null) return const SizedBox.shrink();

    final services = branch.services;
    // Venues the services meet at, in service order; when no service names
    // one, every venue the campus lists.
    final used = <CampusVenue>{
      for (final s in services) ?branch.venueById(s.venueId),
    }.toList();
    final venues = used.isEmpty ? branch.venues : used;
    final legacySchedule = services.isEmpty
        ? formatServiceSchedule(branch.meetingDays, branch.meetingTime)
        : null;
    final legacyAddress = venues.isEmpty ? branch.address?.trim() : null;
    final hasLegacyAddress = legacyAddress != null && legacyAddress.isNotEmpty;
    // Services that name no listed venue lead, outside any venue block.
    final unplaced = [
      for (final s in services)
        if (!venues.any((v) => v.id == s.venueId)) s,
    ];
    // With several venues, a note every one of them carries is said once.
    final shared = venues.length < 2
        ? const <String>[]
        : [
            for (final n in venueNotes(venues.first))
              if (venues.every((v) => venueNotes(v).contains(n))) n,
          ];
    final contact = branch.contact;

    if (services.isEmpty &&
        venues.isEmpty &&
        legacySchedule == null &&
        !hasLegacyAddress &&
        contact.isEmpty) {
      return const SizedBox.shrink();
    }

    final kc = context.kc;
    return Padding(
      padding: padding,
      child: Container(
        key: const Key('campus-card'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: kc.surface,
          borderRadius: AppRadius.cardBorder,
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'YOUR BRANCH',
                  style: AppTypography.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ).copyWith(color: kc.muted, height: 1),
                ),
                const Spacer(),
                Semantics(
                  label: 'Change branch',
                  button: true,
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: () => pickActiveBranch(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: kc.onChip,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Change',
                      style: AppTypography.ui(
                        size: 12.5,
                        weight: FontWeight.w600,
                      ).copyWith(color: kc.onChip, height: 1),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              branch.name,
              style: AppTypography.display(
                size: 22,
                weight: FontWeight.w700,
              ).copyWith(color: kc.onBg, height: 1.1),
            ),
            // One block per venue: its name, the services that meet there,
            // its address and its own notes. Notes every venue shares show
            // once at the end rather than under each.
            if (unplaced.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ServiceList(services: unplaced),
            ] else if (legacySchedule != null) ...[
              const SizedBox(height: 12),
              _IconLine(icon: Icons.schedule_rounded, text: legacySchedule),
            ],
            for (final v in venues) ...[
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: kc.divider),
              _VenueBlock(
                venue: v,
                services: [
                  for (final s in services)
                    if (s.venueId == v.id) s,
                ],
                notes: [
                  for (final n in venueNotes(v))
                    if (!shared.contains(n)) n,
                ],
              ),
            ],
            if (shared.isNotEmpty) ...[
              for (final n in shared) ...[const SizedBox(height: 4), _Note(n)],
            ],
            if (venues.isEmpty && hasLegacyAddress) ...[
              const SizedBox(height: 2),
              _AddressLink(
                key: const Key('campus-directions'),
                text: legacyAddress,
                onTap: () => _openDirections(context, legacyAddress),
              ),
            ],
            if (!contact.isEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (contact.phone case final phone?)
                    _ContactChip(
                      key: const Key('campus-call'),
                      icon: Icons.call_outlined,
                      label: 'Call',
                      semanticsLabel: 'Call $phone',
                      onTap: () => _launch(Uri(scheme: 'tel', path: phone)),
                    ),
                  if (contact.email case final email?)
                    _ContactChip(
                      key: const Key('campus-email'),
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      semanticsLabel: 'Email $email',
                      onTap: () => _launch(Uri(scheme: 'mailto', path: email)),
                    ),
                  if (contact.instagram case final ig?)
                    if (instagramUri(ig) case final uri?)
                      _ContactChip(
                        key: const Key('campus-instagram'),
                        icon: Icons.photo_camera_outlined,
                        label: 'Instagram',
                        semanticsLabel: 'Instagram $ig',
                        onTap: () => _launch(uri),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens [query] in the platform's maps app. A failure to launch is not
/// surfaced: the address stays readable on the card either way.
Future<void> _openDirections(BuildContext context, String query) =>
    _launch(directionsUri(query, platform: defaultTargetPlatform));

Future<void> _launch(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Nothing the member can act on; the details stay on the card.
  }
}

/// A venue's directions, parking and transport notes, blanks dropped.
List<String> venueNotes(CampusVenue venue) => [
  for (final n in [
    venue.directionsText,
    venue.parkingInfo,
    venue.publicTransportInfo,
  ])
    if (n?.trim() case final t? when t.isNotEmpty) t,
];

class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.services});

  final List<CampusService> services;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, s) in services.indexed) ...[
        if (i > 0) const SizedBox(height: 12),
        _ServiceRow(service: s),
      ],
    ],
  );
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service});

  final CampusService service;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final when = campusServiceWhen(service);
    return Row(
      key: Key('campus-service-${service.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kc.chipBg,
            borderRadius: AppRadius.tileBorder,
          ),
          child: Icon(Icons.schedule_rounded, size: 18, color: kc.onChip),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: AppTypography.ui(
                  size: 14.5,
                  weight: FontWeight.w700,
                ).copyWith(color: kc.onBg, height: 1.25),
              ),
              if (when != null) ...[
                const SizedBox(height: 2),
                Text(
                  when,
                  style: AppTypography.ui(
                    size: 13,
                    weight: FontWeight.w500,
                  ).copyWith(color: kc.muted, height: 1.3),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One place the branch meets: its name, the services held there, then its
/// address (tap for directions) and [notes].
class _VenueBlock extends StatelessWidget {
  const _VenueBlock({
    required this.venue,
    required this.services,
    required this.notes,
  });

  final CampusVenue venue;
  final List<CampusService> services;
  final List<String> notes;

  /// What the maps app searches for: the address, else the pin, else the
  /// venue name.
  String? get _query {
    if (venue.address.isNotEmpty) {
      return [?venue.name, venue.address].join(', ');
    }
    if (venue.latitude case final lat?) {
      if (venue.longitude case final lng?) return '$lat,$lng';
    }
    return venue.name;
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final query = _query;
    return Padding(
      key: Key('campus-venue-${venue.id}'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venue.name case final name?) ...[
            Text(
              name,
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w700,
              ).copyWith(color: kc.onBg, height: 1.25),
            ),
            if (services.isNotEmpty) const SizedBox(height: 10),
          ],
          if (services.isNotEmpty) ...[
            _ServiceList(services: services),
            const SizedBox(height: 8),
          ],
          if (query != null)
            _AddressLink(
              key: Key('campus-directions-${venue.id}'),
              text: venue.address.isNotEmpty ? venue.address : 'Get directions',
              onTap: () => _openDirections(context, query),
            ),
          for (final n in notes) ...[const SizedBox(height: 4), _Note(n)],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.ui(
      size: 12.5,
    ).copyWith(color: context.kc.muted, height: 1.35),
  );
}

/// An address that opens directions; tinted so the affordance is visible.
class _AddressLink extends StatelessWidget {
  const _AddressLink({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.kc.onChip;
    return Semantics(
      button: true,
      label: 'Directions to $text',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 10 px above and below lifts a one-line address to a 44 px target.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.directions_outlined, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.ui(
                    size: 13.5,
                    weight: FontWeight.w600,
                  ).copyWith(color: color, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.kc.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.ui(
              size: 13.5,
              weight: FontWeight.w500,
            ).copyWith(color: color, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kc.onBg,
          side: BorderSide(color: kc.outline),
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: AppTypography.ui(size: 13, weight: FontWeight.w700),
        ),
      ),
    );
  }
}
