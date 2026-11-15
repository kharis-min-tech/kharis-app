import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart'
    show directionsUri;
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

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

/// "Your branch" card: when and where the member's branch meets, and how
/// to reach it.
///
/// Reads the Studio's structured [Branch.services] (each with its venue and
/// directions) and [Branch.contact] (call, email, Instagram). A branch with
/// no services yet falls back to the legacy [Branch.meetingDays] /
/// [Branch.meetingTime] / [Branch.address] mirrors.
///
/// With [showHeader] the services sit inside the card under their venue;
/// without it (the Branch page) they follow the card as a timetable.
///
/// Renders nothing when no branch is selected (all-branch view) or the
/// branch has nothing to show, rather than an empty card.
class CampusCard extends ConsumerWidget {
  const CampusCard({
    super.key,
    this.padding = EdgeInsets.zero,
    this.showHeader = true,
    this.homeScope = false,
    this.summary = false,
    this.onTap,
  });

  /// Outer padding, applied only when the card renders, so Home's spacing
  /// collapses with it.
  final EdgeInsetsGeometry padding;

  /// Whether the card leads with "Your branch" and the branch name. Off
  /// where the screen already names the branch (the Branch page's header).
  final bool showHeader;

  /// Show Home's branch ([homeCampusProvider]) rather than the member's
  /// chosen one, as the Branch page opened from Home does.
  final bool homeScope;

  /// The short card on More: the branch name, one address row, one service
  /// row and the two buttons. No contacts, notes or full service list; the
  /// Branch page ([onTap]) has those.
  final bool summary;

  /// Tapping the card itself (its buttons keep their own actions).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(
      homeScope ? homeCampusProvider : currentCampusProvider,
    );
    if (branch == null) return const SizedBox.shrink();

    final services = branch.services;
    // Venues the services meet at, in service order; when no service names
    // one, every venue the branch lists.
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

    // The summary always renders for a chosen branch: it is More's way to
    // change branch.
    if (!summary &&
        services.isEmpty &&
        venues.isEmpty &&
        legacySchedule == null &&
        !hasLegacyAddress &&
        contact.isEmpty) {
      return const SizedBox.shrink();
    }

    final k = context.k;
    List<CampusService> at(CampusVenue v) => [
      for (final s in services)
        if (s.venueId == v.id) s,
    ];
    // Where the Directions button leads: the first venue that can be found
    // on a map, else the legacy address.
    final directions =
        venues.map(venueDirectionsQuery).nonNulls.firstOrNull ??
        (hasLegacyAddress ? legacyAddress : null);

    final buttons = [
      if (directions != null)
        KButton(
          key: const Key('campus-directions-button'),
          label: 'Directions',
          variant: KButtonVariant.inverse,
          expand: true,
          onPressed: () => _openDirections(context, directions),
        ),
      KButton(
        key: Key(homeScope ? 'home-branch-change' : 'campus-change'),
        label: 'Change branch',
        variant: KButtonVariant.outline,
        expand: true,
        onPressed: () => pickActiveBranch(context, ref),
      ),
    ];

    // Side by side at the default size; stacked once text is 130% or more,
    // so neither label is cut.
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >= KRatio.largeTextScale;
    final buttonRow = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, b) in buttons.indexed) ...[
                if (i > 0) const SizedBox(height: KSpace.md),
                b,
              ],
            ],
          )
        : Row(
            children: [
              for (final (i, b) in buttons.indexed) ...[
                if (i > 0) const SizedBox(width: KSpace.md),
                Expanded(child: b),
              ],
            ],
          );

    if (summary) {
      final firstVenue = venues.firstOrNull;
      final address = firstVenue == null
          ? (hasLegacyAddress ? legacyAddress : null)
          : (firstVenue.address.isNotEmpty
                ? firstVenue.address
                : firstVenue.name);
      final service = services.firstOrNull;
      final serviceLine = service == null
          ? legacySchedule
          : [service.name, ?campusServiceWhen(service)].join(' \u00b7 ');
      return Padding(
        padding: padding,
        child: KCard(
          key: const Key('campus-card'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KOverline('Your branch'),
              const SizedBox(height: KSpace.sm),
              Text(
                branch.name,
                style: KharisText.title.copyWith(color: k.text),
              ),
              if (address != null) ...[
                const SizedBox(height: KSpace.md),
                _IconLine(icon: KIcons.pin, text: address),
              ],
              if (serviceLine != null) ...[
                const SizedBox(height: KSpace.md),
                _IconLine(icon: KIcons.calendar, text: serviceLine),
              ],
              const SizedBox(height: KSpace.xl),
              buttonRow,
            ],
          ),
        ),
      );
    }

    final card = KCard(
      key: const Key('campus-card'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            const KOverline('Your branch'),
            const SizedBox(height: KSpace.sm),
            Text(branch.name, style: KharisText.title.copyWith(color: k.text)),
            const SizedBox(height: KSpace.md),
          ],
          // One block per venue: its name, the services that meet there (in
          // the card only when it carries the header), its address and its
          // own notes. Notes every venue shares show once at the end.
          if (showHeader && unplaced.isNotEmpty)
            _ServiceList(services: unplaced)
          else if (legacySchedule != null)
            _IconLine(icon: KIcons.calendar, text: legacySchedule),
          for (final (i, v) in venues.indexed) ...[
            if (i > 0) ...[
              const SizedBox(height: KSpace.xl),
              Divider(height: 1, thickness: 1, color: k.line),
              const SizedBox(height: KSpace.xl),
            ],
            _VenueBlock(
              venue: v,
              services: showHeader ? at(v) : const [],
              notes: [
                for (final n in venueNotes(v))
                  if (!shared.contains(n)) n,
              ],
            ),
          ],
          for (final n in shared) ...[
            const SizedBox(height: KSpace.xs),
            _Note(n),
          ],
          if (venues.isEmpty && hasLegacyAddress)
            _AddressLink(
              key: const Key('campus-directions'),
              text: legacyAddress,
              onTap: () => _openDirections(context, legacyAddress),
            ),
          const SizedBox(height: KSpace.xl),
          buttonRow,
          if (!contact.isEmpty) ...[
            const SizedBox(height: KSpace.xl),
            CampusContactActions(contact: contact),
          ],
        ],
      ),
    );

    return Padding(
      padding: padding,
      child: showHeader || services.isEmpty
          ? card
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                card,
                if (unplaced.isNotEmpty) ...[
                  const SizedBox(height: KSpace.gutter),
                  _Timetable(services: unplaced),
                ],
                for (final v in venues)
                  if (at(v).isNotEmpty) ...[
                    const SizedBox(height: KSpace.gutter),
                    _Timetable(
                      heading: venues.length > 1 ? v.name : null,
                      services: at(v),
                    ),
                  ],
              ],
            ),
    );
  }
}

/// How to reach a branch as compact buttons: Call, Email and Instagram,
/// each only when the Studio set it. Button keys are `$keyPrefix-call`,
/// `$keyPrefix-email` and `$keyPrefix-instagram`.
class CampusContactActions extends StatelessWidget {
  const CampusContactActions({
    super.key,
    required this.contact,
    this.keyPrefix = 'campus',
  });

  final CampusContact contact;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: KSpace.md,
    runSpacing: KSpace.md,
    children: [
      if (contact.phone case final phone?)
        _ContactButton(
          key: Key('$keyPrefix-call'),
          label: 'Call',
          semanticsLabel: 'Call $phone',
          onTap: () => _launch(Uri(scheme: 'tel', path: phone)),
        ),
      if (contact.email case final email?)
        _ContactButton(
          key: Key('$keyPrefix-email'),
          label: 'Email',
          semanticsLabel: 'Email $email',
          onTap: () => _launch(Uri(scheme: 'mailto', path: email)),
        ),
      if (contact.instagram case final ig?)
        if (instagramUri(ig) case final uri?)
          _ContactButton(
            key: Key('$keyPrefix-instagram'),
            label: 'Instagram',
            semanticsLabel: 'Instagram $ig',
            onTap: () => _launch(uri),
          ),
    ],
  );
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
        if (i > 0) const SizedBox(height: KSpace.md),
        _ServiceRow(service: s),
      ],
    ],
  );
}

/// A service inside the card: a small calendar icon, its name and when it
/// meets.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service});

  final CampusService service;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final when = campusServiceWhen(service);
    return MergeSemantics(
      child: Row(
        key: Key('campus-service-${service.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KIcon(KIcons.calendar, size: KSize.iconSm, color: k.muted),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: KharisText.itemTitle.copyWith(color: k.text),
                ),
                if (when != null)
                  Text(when, style: KharisText.meta.copyWith(color: k.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Branch page's timetable: the services as rows in one group, under
/// the venue's name when the branch meets at several.
class _Timetable extends StatelessWidget {
  const _Timetable({required this.services, this.heading});

  final List<CampusService> services;
  final String? heading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading case final text?) ...[
          Semantics(
            header: true,
            child: Text(
              text,
              style: KharisText.caption.copyWith(color: context.k.muted),
            ),
          ),
          const SizedBox(height: KSpace.md),
        ],
        KListGroup(
          children: [
            for (final s in services)
              KListRow(
                key: Key('campus-service-${s.id}'),
                leading: const KIconTile(KIcons.calendar),
                title: s.name,
                meta: campusServiceWhen(s),
              ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      key: Key('campus-venue-${venue.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (venue.name case final name?) ...[
          Text(name, style: KharisText.itemTitle.copyWith(color: k.text)),
          if (services.isNotEmpty) const SizedBox(height: KSpace.md),
        ],
        if (services.isNotEmpty) _ServiceList(services: services),
        if (venueDirectionsQuery(venue) != null)
          VenueDirectionsLink(
            key: Key('campus-directions-${venue.id}'),
            venue: venue,
          ),
        for (final n in notes) ...[const SizedBox(height: KSpace.xs), _Note(n)],
      ],
    );
  }
}

/// What the maps app searches for to reach [venue]: its address, else its
/// pin, else its name; null when the Studio set none of them.
String? venueDirectionsQuery(CampusVenue venue) {
  if (venue.address.isNotEmpty) {
    return [?venue.name, venue.address].join(', ');
  }
  if (venue.latitude case final lat?) {
    if (venue.longitude case final lng?) return '$lat,$lng';
  }
  return venue.name;
}

/// [venue]'s address (or "Get directions"), opening the maps app on tap.
/// Renders nothing when [venueDirectionsQuery] has nothing to search for.
class VenueDirectionsLink extends StatelessWidget {
  const VenueDirectionsLink({super.key, required this.venue});

  final CampusVenue venue;

  @override
  Widget build(BuildContext context) {
    final query = venueDirectionsQuery(venue);
    if (query == null) return const SizedBox.shrink();
    return _AddressLink(
      text: venue.address.isNotEmpty ? venue.address : 'Get directions',
      onTap: () => _openDirections(context, query),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: KharisText.meta.copyWith(color: context.k.muted));
}

/// An address that opens directions: a pin and the address, 44 tall.
class _AddressLink extends StatelessWidget {
  const _AddressLink({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      button: true,
      label: 'Directions to $text',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSize.touchMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
            child: Row(
              children: [
                KIcon(KIcons.pin, size: KSize.iconSm, color: k.muted),
                const SizedBox(width: KSpace.md),
                Expanded(
                  child: Text(
                    text,
                    style: KharisText.meta.copyWith(color: k.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KIcon(icon, size: KSize.iconSm, color: k.muted),
        const SizedBox(width: KSpace.md),
        Expanded(
          child: Text(text, style: KharisText.meta.copyWith(color: k.muted)),
        ),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: KButton(
        label: label,
        variant: KButtonVariant.outline,
        onPressed: onTap,
      ),
    );
  }
}
