import 'package:flutter/material.dart';
import 'package:kharis_app/core/services/content_api.dart';
import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// A church branch, as published in the Kharis Content Studio.
///
/// [contact], [venues], [services] and [giving] come from the Studio's
/// `branches`, `services` and `venues` tables. The flat [address] /
/// [meetingDays] / [meetingTime] are kept for widgets that show a one-line
/// summary; [address] is the first service venue's address.
@immutable
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.gradientStart,
    required this.gradientEnd,
    this.imageUrl,
    this.order = 0,
    this.address,
    this.meetingDays,
    this.meetingTime,
    this.group = mainGroup,
    this.contact = const CampusContact(),
    this.venues = const [],
    this.services = const [],
    this.giving,
    this.home,
  });

  /// [group] of the main Kharis branches.
  static const String mainGroup = 'Kharis';

  /// [group] of the Kharis Phase Two (KP2) branches; the Studio calls the
  /// group "Kharis Phase 2".
  static const String phaseTwoGroup = 'KP2';

  /// Studio slug, e.g. `london` or `kp2-barking`.
  final String id;

  /// Display name. Also the member's stored branch choice and the source of
  /// the FCM branch topic, so it is the key screens match branches by.
  final String name;
  final String subtitle;
  final Color gradientStart;
  final Color gradientEnd;

  /// Hero image; null when the Studio has no usable URL for it.
  final String? imageUrl;
  final int order;
  final String? address;
  final String? meetingDays;
  final String? meetingTime;

  /// [mainGroup] or [phaseTwoGroup].
  final String group;
  final CampusContact contact;
  final List<CampusVenue> venues;

  /// Active services in Studio order.
  final List<CampusService> services;

  /// Branch giving page; null gives to the church-wide account.
  final GivingDetails? giving;

  /// Branch Home layout. The Content Studio has none, so this is null and
  /// Home shows [HomeLayout.fallback].
  final HomeLayout? home;

  /// The venue a service meets at, if [venueId] names one.
  CampusVenue? venueById(String? venueId) {
    if (venueId == null) return null;
    for (final v in venues) {
      if (v.id == venueId) return v;
    }
    return null;
  }

  List<Color> get gradient => [gradientStart, gradientEnd];

  static Color parseHex(String? hex, Color fallback) {
    if (hex == null) return fallback;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }
}

const _weekdays = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

/// 0 = Sunday ... 6 = Saturday for a day name ("Sunday", "Sundays", "sun").
int? weekdayIndex(String? day) {
  final d = day?.trim().toLowerCase();
  if (d == null || d.length < 3) return null;
  for (var i = 0; i < _weekdays.length; i++) {
    if (_weekdays[i].startsWith(d.substring(0, 3))) return i;
  }
  return null;
}

/// Main branches before KP2, then Studio order, then name.
int compareBranches(Branch a, Branch b) {
  int rank(Branch x) => x.group == Branch.phaseTwoGroup ? 1 : 0;
  final byGroup = rank(a).compareTo(rank(b));
  if (byGroup != 0) return byGroup;
  final byOrder = a.order.compareTo(b.order);
  return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
}

/// Reads branches, with their services and venues, from the Content Studio.
class BranchRepository {
  BranchRepository({required this._api});

  final ContentApi _api;

  static const _branchQuery = {'is_active': 'eq.true'};
  static const _serviceQuery = {'is_active': 'eq.true'};

  /// The last known branches first (when saved on this device), then the
  /// Studio's current ones. Errors only when neither is available.
  Stream<List<Branch>> watchBranches() async* {
    final branches = _api.cached('branches');
    final saved = branches == null
        ? null
        : joinBranches(
            branches,
            services: _api.cached('services') ?? const [],
            venues: _api.cached('venues') ?? const [],
          );
    if (saved != null) yield saved;
    try {
      final rows = await Future.wait([
        _api.fetch('branches', query: _branchQuery),
        _api.fetch('services', query: _serviceQuery),
        _api.fetch('venues'),
      ]);
      yield joinBranches(rows[0], services: rows[1], venues: rows[2]);
    } catch (_) {
      if (saved == null) rethrow;
    }
  }

  /// Joins Studio rows into [Branch]es: active branches only, main branches
  /// before KP2, each group in Studio order.
  static List<Branch> joinBranches(
    List<Map<String, dynamic>> branches, {
    required List<Map<String, dynamic>> services,
    required List<Map<String, dynamic>> venues,
  }) {
    final venuesByBranch = <String, List<CampusVenue>>{};
    for (final v in venues) {
      final branchId = _text(v['branch_id']);
      final venue = _venue(v);
      if (branchId == null || venue == null) continue;
      (venuesByBranch[branchId] ??= []).add(venue);
    }
    final servicesByBranch = <String, List<CampusService>>{};
    for (final s in services) {
      final branchId = _text(s['branch_id']);
      final service = _service(s);
      if (branchId == null || service == null || !service.isActive) continue;
      (servicesByBranch[branchId] ??= []).add(service);
    }
    final result = <Branch>[];
    for (final b in branches) {
      if (b['is_active'] != true) continue;
      final uuid = _text(b['id']);
      final slug = _text(b['slug']) ?? uuid;
      final name = _text(b['name']);
      if (uuid == null || slug == null || name == null) continue;
      final branchServices = [...?servicesByBranch[uuid]]
        ..sort((x, y) {
          final byOrder = x.order.compareTo(y.order);
          if (byOrder != 0) return byOrder;
          final byDay = (weekdayIndex(x.day) ?? 7).compareTo(
            weekdayIndex(y.day) ?? 7,
          );
          if (byDay != 0) return byDay;
          return (x.startTime ?? '').compareTo(y.startTime ?? '');
        });
      final branchVenues = venuesByBranch[uuid] ?? const <CampusVenue>[];
      result.add(_branch(b, slug, name, branchServices, branchVenues));
    }
    return result..sort(compareBranches);
  }

  static Branch _branch(
    Map<String, dynamic> b,
    String slug,
    String name,
    List<CampusService> services,
    List<CampusVenue> venues,
  ) {
    CampusVenue? firstVenue;
    for (final s in services) {
      for (final v in venues) {
        if (v.id == s.venueId) {
          firstVenue = v;
          break;
        }
      }
      if (firstVenue != null) break;
    }
    firstVenue ??= venues.isEmpty ? null : venues.first;
    final address = firstVenue?.address;
    final givingUrl = usableMediaUrl(_text(b['giving_link']));
    return Branch(
      id: slug,
      name: name,
      subtitle: _text(b['subtitle']) ?? _text(b['short_description']) ?? '',
      gradientStart: Branch.parseHex(
        _text(b['gradient_start']),
        const Color(0xFF3B2A6B),
      ),
      gradientEnd: Branch.parseHex(
        _text(b['gradient_end']),
        const Color(0xFF7C3AED),
      ),
      imageUrl: usableMediaUrl(_text(b['hero_image_url'])),
      order: (b['sort_order'] as num?)?.toInt() ?? 0,
      address: address == null || address.isEmpty ? null : address,
      group: _group(_text(b['group'])),
      contact: CampusContact(
        email: _text(b['contact_email']),
        phone: _text(b['contact_phone']),
        instagram: _text(b['instagram']),
      ),
      venues: venues,
      services: services,
      giving: givingUrl == null ? null : GivingDetails(url: givingUrl),
    );
  }

  /// "Kharis Phase 2" (or anything naming KP2) is [Branch.phaseTwoGroup];
  /// everything else is a main branch.
  static String _group(String? raw) {
    final g = raw?.toLowerCase() ?? '';
    return g.contains('phase 2') || g.contains('phase two') || g.contains('kp2')
        ? Branch.phaseTwoGroup
        : Branch.mainGroup;
  }

  static CampusVenue? _venue(Map<String, dynamic> v) {
    final id = _text(v['id']);
    if (id == null) return null;
    double? number(Object? x) => x is num ? x.toDouble() : null;
    return CampusVenue(
      id: id,
      name: _text(v['name']),
      addressLine1: _text(v['address_line1']),
      addressLine2: _text(v['address_line2']),
      city: _text(v['city']),
      postcode: _text(v['postcode']),
      country: _text(v['country']),
      latitude: number(v['latitude']),
      longitude: number(v['longitude']),
      parkingInfo: _text(v['parking_info']),
      publicTransportInfo: _text(v['public_transport_info']),
      directionsText: _text(v['directions_text']),
    );
  }

  static CampusService? _service(Map<String, dynamic> s) {
    final id = _text(s['id']);
    final name = _text(s['name']);
    if (id == null || name == null) return null;
    return CampusService(
      id: id,
      name: name,
      type: _text(s['type']),
      day: _text(s['day']),
      startTime: _clock(s['start_time']),
      endTime: _clock(s['end_time']),
      venueId: _text(s['venue_id']),
      description: _text(s['description']),
      order: (s['sort_order'] as num?)?.toInt() ?? 0,
      isActive: s['is_active'] != false,
    );
  }

  /// Postgres `time` ("14:00:00") as "14:00", which the service-time
  /// formatter shows as "2:00 PM". Anything else passes through.
  static String? _clock(Object? raw) {
    final t = _text(raw);
    if (t == null) return null;
    final m = RegExp(r'^(\d{2}:\d{2}):\d{2}(\.\d+)?$').firstMatch(t);
    return m == null ? t : m.group(1);
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
