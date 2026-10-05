import 'package:flutter/foundation.dart';

/// Per-campus configuration carried on `branches/{id}` (and church-wide
/// defaults in `config/*`). One definition shared by the member app (read
/// side) and the in-app Studio (write side); the web Studio writes the same
/// JSON shapes.

String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

Map<String, Object?> _withoutNulls(Map<String, Object?> m) => {
  for (final e in m.entries)
    if (e.value != null) e.key: e.value,
};

// ── Giving ────────────────────────────────────────────────────────────────────

/// Where a gift goes: `branches/{id}.giving`, else `config/giving`, else the
/// built-in church-wide details. A campus with no `giving` map gives to the
/// church-wide account.
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

  /// Parses a `giving` map; null (or an empty map) means "not set here".
  static GivingDetails? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final g = GivingDetails(
      url: _https(raw['url']),
      bankName: _text(raw['bankName']),
      accountName: _text(raw['accountName']),
      sortCode: _text(raw['sortCode']),
      accountNumber: _text(raw['accountNumber']),
      swiftBic: _text(raw['swiftBic']),
      iban: _text(raw['iban']),
      reference: _text(raw['reference']),
      note: _text(raw['note']),
    );
    return g.isEmpty ? null : g;
  }

  static String? _https(Object? v) {
    final t = _text(v);
    return t != null && RegExp(r'^https?://', caseSensitive: false).hasMatch(t)
        ? t
        : null;
  }

  Map<String, Object?> toJson() => _withoutNulls({
    'url': url,
    'bankName': bankName,
    'accountName': accountName,
    'sortCode': sortCode,
    'accountNumber': accountNumber,
    'swiftBic': swiftBic,
    'iban': iban,
    'reference': reference,
    'note': note,
  });

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

/// `branches/{id}.contact` (+ top-level `instagram`), as the web Studio
/// writes them.
@immutable
class CampusContact {
  const CampusContact({this.email, this.phone, this.instagram});

  final String? email;
  final String? phone;
  final String? instagram;

  bool get isEmpty => email == null && phone == null && instagram == null;

  static CampusContact fromBranchJson(Map<String, dynamic> branch) {
    final c = branch['contact'];
    return CampusContact(
      email: c is Map ? _text(c['email']) : null,
      phone: c is Map ? _text(c['phone']) : null,
      instagram: _text(branch['instagram']),
    );
  }

  /// The `contact` map only; `instagram` is a top-level branch field.
  Map<String, Object?> toJson() => {'email': email, 'phone': phone};
}

/// One entry of `branches/{id}.venues`.
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

  /// Address lines joined for display / maps search.
  String get address => [
    addressLine1,
    addressLine2,
    city,
    postcode,
  ].whereType<String>().join(', ');

  static CampusVenue? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = _text(raw['id']);
    if (id == null) return null;
    double? num_(Object? v) => v is num ? v.toDouble() : null;
    return CampusVenue(
      id: id,
      name: _text(raw['name']),
      addressLine1: _text(raw['addressLine1']),
      addressLine2: _text(raw['addressLine2']),
      city: _text(raw['city']),
      postcode: _text(raw['postcode']),
      country: _text(raw['country']),
      latitude: num_(raw['latitude']),
      longitude: num_(raw['longitude']),
      parkingInfo: _text(raw['parkingInfo']),
      publicTransportInfo: _text(raw['publicTransportInfo']),
      directionsText: _text(raw['directionsText']),
    );
  }
}

/// One entry of `branches/{id}.services`. `day` is free text as the web
/// Studio stores it ("Sundays", "Wednesday"); times are "10:00 AM" or "15:00".
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

  static CampusService? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = _text(raw['id']) ?? _text(raw['name']);
    final name = _text(raw['name']) ?? id;
    if (id == null || name == null) return null;
    return CampusService(
      id: id,
      name: name,
      type: _text(raw['type']),
      day: _text(raw['day']),
      startTime: _text(raw['startTime']),
      endTime: _text(raw['endTime']),
      venueId: _text(raw['venueId']),
      description: _text(raw['description']),
      order: raw['order'] is num ? (raw['order'] as num).toInt() : 0,
      isActive: raw['isActive'] != false,
    );
  }

  /// The web Studio's entry shape: blank text fields are `''`, a missing
  /// venue is `null`.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type ?? '',
    'day': day ?? '',
    'startTime': startTime ?? '',
    'endTime': endTime ?? '',
    'venueId': venueId,
    'description': description ?? '',
    'order': order,
    'isActive': isActive,
  };

  /// Active services in Studio order.
  static List<CampusService> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(fromJson)
        .whereType<CampusService>()
        .where((s) => s.isActive)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}

// ── Home layout ──────────────────────────────────────────────────────────────

/// Blocks the Home tab can show. Stored by [id] in `home.sections`.
enum HomeSectionId {
  /// Profile nudge after sign-up; renders only while the profile is
  /// incomplete.
  profileCompletion('profileCompletion', 'Complete your profile'),

  /// "We're live" banner; renders only while `config/live` says so.
  live('live', 'Live now'),

  /// Today's Bible reading.
  reading('reading', 'Bible reading of the day'),

  /// Campus + church-wide announcements.
  announcements('announcements', 'Announcements'),

  /// Upcoming events for the campus.
  events('events', 'Upcoming events'),

  /// Venue, service times and contact for the member's campus.
  campus('campus', 'Your branch'),

  /// Resume the last message; renders only when there is one.
  continueListening('continueListening', 'Continue listening'),

  /// Shortcut into Giving for the member's campus.
  giving('giving', 'Giving');

  const HomeSectionId(this.id, this.label);

  final String id;

  /// Studio-facing label.
  final String label;

  static HomeSectionId? parse(Object? raw) {
    for (final s in values) {
      if (s.id == raw) return s;
    }
    return null;
  }
}

@immutable
class HomeSection {
  const HomeSection(this.id, {this.enabled = true});

  final HomeSectionId id;
  final bool enabled;

  Map<String, Object?> toJson() => {'id': id.id, 'enabled': enabled};

  @override
  bool operator ==(Object other) =>
      other is HomeSection && other.id == id && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, enabled);
}

/// Ordered Home blocks: `branches/{id}.home`, else `config/home`, else
/// [HomeLayout.fallback]. Stored as `{sections: [{id, enabled}]}`.
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

  /// Parses a `home` map; null when absent or unusable. Unknown ids are
  /// dropped and duplicates keep their first position. Any section the
  /// stored list omits (added in a later app version) is appended disabled,
  /// so Studio always shows every block and new blocks never appear
  /// unannounced.
  static HomeLayout? fromJson(Object? raw) {
    if (raw is! Map || raw['sections'] is! List) return null;
    final seen = <HomeSectionId>{};
    final sections = <HomeSection>[];
    for (final e in raw['sections'] as List) {
      if (e is! Map) continue;
      final id = HomeSectionId.parse(e['id']);
      if (id == null || !seen.add(id)) continue;
      sections.add(HomeSection(id, enabled: e['enabled'] != false));
    }
    if (sections.isEmpty) return null;
    for (final id in HomeSectionId.values) {
      if (!seen.contains(id)) sections.add(HomeSection(id, enabled: false));
    }
    return HomeLayout(sections);
  }

  Map<String, Object?> toJson() => {
    'sections': [for (final s in sections) s.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is HomeLayout && listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hashAll(sections);
}

// ── Studio access ────────────────────────────────────────────────────────────

/// What the signed-in user may manage in Content Studio.
///
/// - Super admin: `users/{uid}.role == 'admin'` or the `admin` custom claim;
///   manages everything.
/// - Campus admin: `role == 'campus_admin'` with `adminBranchIds` (branch doc
///   ids) and `adminBranchNames` (the matching names, which is what
///   `news.branch` / `events.branch` hold). Manages only those campuses'
///   announcements, events and branch details (not name/order/group/active).
@immutable
class AdminScope {
  const AdminScope.none()
    : isSuperAdmin = false,
      branchIds = const {},
      branchNames = const {};

  const AdminScope.superAdmin()
    : isSuperAdmin = true,
      branchIds = const {},
      branchNames = const {};

  const AdminScope.campus({required this.branchIds, required this.branchNames})
    : isSuperAdmin = false;

  final bool isSuperAdmin;
  final Set<String> branchIds;
  final Set<String> branchNames;

  bool get isCampusAdmin => !isSuperAdmin && branchIds.isNotEmpty;
  bool get canUseStudio => isSuperAdmin || isCampusAdmin;

  /// May manage content scoped to the campus named [branchName]; null means
  /// all-campus content, which only a super admin may touch.
  bool canManageCampusNamed(String? branchName) =>
      isSuperAdmin || (branchName != null && branchNames.contains(branchName));

  bool canManageBranchId(String branchId) =>
      isSuperAdmin || branchIds.contains(branchId);

  static const campusAdminRole = 'campus_admin';

  /// Scope from a `users/{uid}` profile and the `admin` claim.
  static AdminScope fromProfile(
    Map<String, dynamic>? profile, {
    bool adminClaim = false,
  }) {
    if (adminClaim || profile?['role'] == 'admin') {
      return const AdminScope.superAdmin();
    }
    if (profile?['role'] != campusAdminRole) return const AdminScope.none();
    Set<String> strings(Object? v) => v is List
        ? v.whereType<String>().where((s) => s.trim().isNotEmpty).toSet()
        : const {};
    final ids = strings(profile?['adminBranchIds']);
    final names = strings(profile?['adminBranchNames']);
    if (ids.isEmpty) return const AdminScope.none();
    return AdminScope.campus(branchIds: ids, branchNames: names);
  }
}
