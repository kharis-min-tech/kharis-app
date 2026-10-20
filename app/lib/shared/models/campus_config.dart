import 'package:flutter/foundation.dart';

/// Per-branch settings the member app shows: giving, contact, venues,
/// services (filled from the Content Studio by `BranchRepository`) and the
/// Home layout.

// ── Giving ────────────────────────────────────────────────────────────────────

/// Where a gift goes: the branch's giving link, else the built-in
/// church-wide details (`kBuiltInGiving`).
@immutable
class GivingDetails {
  const GivingDetails({
    this.url,
    this.bankName,
    this.accountName,
    this.sortCode,
    this.accountNumber,
    this.swiftBic,
    this.iban,
    this.reference,
    this.note,
  });

  /// Secure online giving page (https). Null hides "Give securely".
  final String? url;
  final String? bankName;
  final String? accountName;
  final String? sortCode;
  final String? accountNumber;

  /// International transfers (e.g. members giving from Ghana or Sierra
  /// Leone).
  final String? swiftBic;
  final String? iban;

  /// Payment reference members should use, e.g. "LONDON TITHE".
  final String? reference;

  /// Short free text shown under the bank details.
  final String? note;

  bool get hasBankTransfer => accountName != null && accountNumber != null;
  bool get isEmpty => url == null && !hasBankTransfer;

  @override
  bool operator ==(Object other) =>
      other is GivingDetails &&
      other.url == url &&
      other.bankName == bankName &&
      other.accountName == accountName &&
      other.sortCode == sortCode &&
      other.accountNumber == accountNumber &&
      other.swiftBic == swiftBic &&
      other.iban == iban &&
      other.reference == reference &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    url,
    bankName,
    accountName,
    sortCode,
    accountNumber,
    swiftBic,
    iban,
    reference,
    note,
  );
}

// ── Contact, venues, services ────────────────────────────────────────────────

/// How to reach a branch.
@immutable
class CampusContact {
  const CampusContact({this.email, this.phone, this.instagram});

  final String? email;
  final String? phone;
  final String? instagram;

  bool get isEmpty => email == null && phone == null && instagram == null;
}

/// Where a branch meets.
@immutable
class CampusVenue {
  const CampusVenue({
    required this.id,
    this.name,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.postcode,
    this.country,
    this.latitude,
    this.longitude,
    this.parkingInfo,
    this.publicTransportInfo,
    this.directionsText,
  });

  final String id;
  final String? name;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? postcode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? parkingInfo;
  final String? publicTransportInfo;
  final String? directionsText;

  /// Address lines joined for display / maps search. Each line may hold
  /// several comma-separated parts; a part repeated across lines (the Studio
  /// allows "6 Ashley Road" then "6 Ashley Road, St. Paul's") shows once.
  String get address {
    final seen = <String>{};
    return [
      for (final line in [addressLine1, addressLine2, city, postcode])
        if (line != null)
          for (final part in line.split(','))
            if (part.trim().replaceAll(RegExp(r'\s+'), ' ') case final p
                when p.isNotEmpty && seen.add(p.toLowerCase()))
              p,
    ].join(', ');
  }
}

/// One weekly service of a branch. [day] is a weekday name ("Sunday");
/// times are 24-hour "14:00".
@immutable
class CampusService {
  const CampusService({
    required this.id,
    required this.name,
    this.type,
    this.day,
    this.startTime,
    this.endTime,
    this.venueId,
    this.description,
    this.order = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? type;
  final String? day;
  final String? startTime;
  final String? endTime;
  final String? venueId;
  final String? description;
  final int order;
  final bool isActive;
}

// ── Home layout ──────────────────────────────────────────────────────────────

/// Blocks the Home tab can show.
enum HomeSectionId {
  /// Profile nudge after sign-up; renders only while the profile is
  /// incomplete.
  profileCompletion,

  /// "We're live" banner; renders only while the Studio's live stream is on.
  live,

  /// Today's Bible reading.
  reading,

  /// Campus + church-wide announcements.
  announcements,

  /// Upcoming events for the campus.
  events,

  /// Venue, service times and contact for the member's campus.
  campus,

  /// Resume the last message; renders only when there is one.
  continueListening,

  /// Shortcut into Giving for the member's campus.
  giving,
}

@immutable
class HomeSection {
  const HomeSection(this.id, {this.enabled = true});

  final HomeSectionId id;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is HomeSection && other.id == id && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, enabled);
}

/// Ordered Home blocks: the branch layout, else [HomeLayout.fallback].
@immutable
class HomeLayout {
  const HomeLayout(this.sections);

  final List<HomeSection> sections;

  /// Built-in order when Studio has set nothing.
  static const fallback = HomeLayout([
    HomeSection(HomeSectionId.profileCompletion),
    HomeSection(HomeSectionId.live),
    HomeSection(HomeSectionId.reading),
    HomeSection(HomeSectionId.announcements),
    HomeSection(HomeSectionId.events),
    HomeSection(HomeSectionId.campus),
    HomeSection(HomeSectionId.continueListening),
    HomeSection(HomeSectionId.giving, enabled: false),
  ]);

  /// Enabled blocks in order.
  List<HomeSectionId> get visible => [
    for (final s in sections)
      if (s.enabled) s.id,
  ];

  @override
  bool operator ==(Object other) =>
      other is HomeLayout && listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hashAll(sections);
}
