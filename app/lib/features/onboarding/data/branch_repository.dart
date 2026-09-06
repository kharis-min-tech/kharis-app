import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/core/constants/app_assets.dart';

/// A church branch / campus. Gradient colours and a landmark image are stored
/// as plain strings in Firestore so admins can edit them, and parsed here.
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
    this.group = 'Kharis',
  });

  final String id;
  final String name;
  final String subtitle;
  final Color gradientStart;
  final Color gradientEnd;
  final String? imageUrl;
  final int order;
  final String? address;
  final String? meetingDays;
  final String? meetingTime;
  final String group;

  List<Color> get gradient => [gradientStart, gradientEnd];

  static Color parseHex(String? hex, Color fallback) {
    if (hex == null) return fallback;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }

  static String toHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Reads and writes the Firestore `branches` collection. Falls back to the
/// built-in [seedBranches] when the collection is empty or unreachable so the
/// onboarding branch picker always has content.
class BranchRepository {
  BranchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _apiUrl = ApiConfig.getBranches;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Stream<List<Branch>> watchBranches() async* {
    // API-first: one-shot fetch from the Cloud Functions endpoint so content
    // appears even when Firestore is cold/unreachable, then hand over to the
    // realtime Firestore stream below.
    final apiBranches = await _fetchFromApi();
    if (apiBranches != null && apiBranches.isNotEmpty) yield apiBranches;
    try {
      yield* _firestore
          .collection('branches')
          .orderBy('order')
          .snapshots()
          .map((snap) {
        final live = snap.docs.map((d) => _map(d.id, d.data())).toList();
        return _mergeWithSeed(live);
      });
    } catch (_) {
      yield seedBranches;
    }
  }

  /// Overlays live Firestore branches onto the bundled network by id.
  ///
  /// The bundled [seedBranches] guarantee the full Kharis + KP2 network stays
  /// visible even when the live collection holds only a partial migration,
  /// while any branch the admin has edited or added wins over its seed twin.
  /// This replaces an earlier all-or-nothing swap that discarded every live
  /// document unless a KP2 branch existed, which silently reverted admin edits.
  static List<Branch> _mergeWithSeed(List<Branch> live) {
    if (live.isEmpty) return seedBranches;
    final byId = <String, Branch>{
      for (final b in seedBranches) b.id: b,
      for (final b in live) b.id: b,
    };
    return byId.values.toList()
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
  }

  /// One-shot fetch from the `getBranches` API. Returns `null` on any
  /// failure so callers fall straight through to Firestore.
  Future<List<Branch>?> _fetchFromApi() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_apiUrl);
      final raw = (res.data?['branches'] as List?) ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((j) => _map((j['id'] as String?) ?? '', j))
          .where((b) => b.id.isNotEmpty)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (_) {
      return null;
    }
  }

  Future<void> addBranch({
    required String name,
    required String subtitle,
    required Color gradientStart,
    required Color gradientEnd,
    String? imageUrl,
    int order = 99,
    String? address,
    String? meetingDays,
    String? meetingTime,
    String group = 'Kharis',
  }) {
    return _firestore.collection('branches').add(_data(
          name: name,
          subtitle: subtitle,
          gradientStart: gradientStart,
          gradientEnd: gradientEnd,
          imageUrl: imageUrl,
          order: order,
          address: address,
          meetingDays: meetingDays,
          meetingTime: meetingTime,
          group: group,
        ));
  }

  Future<void> updateBranch(
    String id, {
    required String name,
    required String subtitle,
    required Color gradientStart,
    required Color gradientEnd,
    String? imageUrl,
    int order = 99,
    String? address,
    String? meetingDays,
    String? meetingTime,
    String group = 'Kharis',
  }) {
    return _firestore.collection('branches').doc(id).update(_data(
          name: name,
          subtitle: subtitle,
          gradientStart: gradientStart,
          gradientEnd: gradientEnd,
          imageUrl: imageUrl,
          order: order,
          address: address,
          meetingDays: meetingDays,
          meetingTime: meetingTime,
          group: group,
        ));
  }

  Future<void> deleteBranch(String id) =>
      _firestore.collection('branches').doc(id).delete();

  Map<String, Object?> _data({
    required String name,
    required String subtitle,
    required Color gradientStart,
    required Color gradientEnd,
    String? imageUrl,
    required int order,
    String? address,
    String? meetingDays,
    String? meetingTime,
    String group = 'Kharis',
  }) =>
      {
        'name': name,
        'subtitle': subtitle,
        'gradientStart': Branch.toHex(gradientStart),
        'gradientEnd': Branch.toHex(gradientEnd),
        'imageUrl': imageUrl,
        'order': order,
        'address': address,
        'meetingDays': meetingDays,
        'meetingTime': meetingTime,
        'group': group,
      };

  Branch _map(String id, Map<String, dynamic> data) => Branch(
        id: id,
        name: data['name'] as String? ?? '',
        // The web portal offers `subtitle`, `shortDescription` and a full
        // `description`; legacy docs used `location`. `description` is now a
        // paragraph in the Studio's branch schema, so it sinks to last resort:
        // promoting it would put a whole paragraph on the branch card whenever
        // an admin left the subtitle blank.
        subtitle: data['subtitle'] as String? ??
            data['shortDescription'] as String? ??
            data['location'] as String? ??
            data['description'] as String? ??
            '',
        gradientStart:
            Branch.parseHex(data['gradientStart'] as String?, const Color(0xFF3B2A6B)),
        gradientEnd:
            Branch.parseHex(data['gradientEnd'] as String?, const Color(0xFF7C3AED)),
        imageUrl: data['imageUrl'] as String?,
        order: (data['order'] as num?)?.toInt() ?? 0,
        address: data['address'] as String?,
        meetingDays: data['meetingDays'] as String?,
        meetingTime: data['meetingTime'] as String?,
        group: data['group'] as String? ?? 'Kharis',
      );

  /// Built-in branches — the real Kharis network (kharis.org), used to seed
  /// Firestore and as an offline fallback. Landmark photos are bundled under
  /// `assets/design` and resolved via [AppAssets.city]; admins may override
  /// with a hosted URL from the CMS.
  static const _gA = Color(0xFF3B2A6B);
  static const _gB = Color(0xFF7C3AED);

  static final List<Branch> seedBranches = [
    // ── Kharis main branches ────────────────────────────────────────────────
    Branch(
      id: 'london-hq',
      name: 'London',
      subtitle: 'United Kingdom · Main Campus',
      gradientStart: _gA,
      gradientEnd: _gB,
      imageUrl: AppAssets.city('london-hq'),
      order: 0,
      address: 'Kensington Town Hall, Hornton St, London W8 7NX',
      meetingDays: 'Sundays',
      meetingTime: '10:00 AM',
    ),
    Branch(id: 'birmingham', name: 'Birmingham', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('birmingham'), order: 1),
    Branch(id: 'brighton', name: 'Brighton', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('brighton'), order: 2),
    Branch(id: 'bristol', name: 'Bristol', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('bristol'), order: 3),
    Branch(id: 'chatham', name: 'Chatham', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('chatham'), order: 4),
    Branch(id: 'chelmsford', name: 'Chelmsford', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('chelmsford'), order: 5),
    Branch(id: 'coventry', name: 'Coventry', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('coventry'), order: 6),
    Branch(id: 'croydon', name: 'Croydon', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('croydon'), order: 7),
    Branch(id: 'luton', name: 'Luton', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('luton'), order: 8),
    Branch(id: 'manchester', name: 'Manchester', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('manchester'), order: 9),
    Branch(id: 'northampton', name: 'Northampton', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('northampton'), order: 10),
    Branch(id: 'nottingham', name: 'Nottingham', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('nottingham'), order: 11),
    Branch(id: 'orpington', name: 'Orpington', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('orpington'), order: 12),
    Branch(id: 'reading', name: 'Reading', subtitle: 'United Kingdom', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('reading'), order: 13),
    Branch(id: 'accra', name: 'Accra', subtitle: 'Ghana', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('accra'), order: 14),
    Branch(id: 'freetown', name: 'Freetown', subtitle: 'Sierra Leone', gradientStart: _gA, gradientEnd: _gB, imageUrl: AppAssets.city('freetown'), order: 15),
    // ── Kharis Phase Two (KP2) — young-adults revival ────────────────────────
    Branch(
      id: 'kp2-london',
      name: 'KP2 London',
      subtitle: 'United Kingdom',
      group: 'KP2',
      gradientStart: _gA,
      gradientEnd: _gB,
      imageUrl: AppAssets.city('kp2-london'),
      order: 20,
      address: 'Kensington Town Hall, Hornton St, London W8 7NX',
      meetingDays: 'Sundays',
      meetingTime: '2:00 PM',
    ),
    Branch(
      id: 'kp2-romford',
      name: 'KP2 Romford',
      subtitle: 'United Kingdom',
      group: 'KP2',
      gradientStart: _gA,
      gradientEnd: _gB,
      imageUrl: AppAssets.city('kp2-romford'),
      order: 21,
      address: 'Marshalls Park Academy, Pettits Ln, Romford RM1 4EH',
      meetingDays: 'Sundays',
      meetingTime: '1:00 PM',
    ),
    Branch(
      id: 'kp2-peterborough',
      name: 'KP2 Peterborough',
      subtitle: 'United Kingdom',
      group: 'KP2',
      gradientStart: _gA,
      gradientEnd: _gB,
      imageUrl: AppAssets.city('kp2-peterborough'),
      order: 22,
      address: 'Thomas Deacon Academy, Queens Gardens, Peterborough PE1 2UW',
      meetingDays: 'Sundays',
      meetingTime: '2:00 PM',
    ),
    Branch(
      id: 'kp2-birmingham',
      name: 'KP2 Birmingham',
      subtitle: 'United Kingdom',
      group: 'KP2',
      gradientStart: _gA,
      gradientEnd: _gB,
      imageUrl: AppAssets.city('birmingham'),
      order: 23,
      address: 'Erdington Methodist Church, Erdington, Birmingham B23 6TX',
      meetingDays: 'Sundays',
      meetingTime: '1:00 PM',
    ),
    Branch(
      id: 'kp2-southampton',
      name: 'KP2 Southampton',
      subtitle: 'United Kingdom',
      group: 'KP2',
      gradientStart: _gA,
      gradientEnd: _gB,
      imageUrl: AppAssets.city('kp2-southampton'),
      order: 24,
      address: 'River Church, 131A Northam Road, Southampton SO14 0HQ',
      meetingDays: 'Sundays',
      meetingTime: '2:00 PM',
    ),
    Branch(
      id: 'kp2-barking',
      name: 'KP2 Barking',
      subtitle: 'United Kingdom',
      group: 'KP2',
      gradientStart: _gA,
      gradientEnd: _gB,
      imageUrl: AppAssets.city('kp2-barking'),
      order: 25,
      address: 'Greatfields School, Net St, Barking IG11 7QG',
      meetingDays: 'Sundays',
      meetingTime: '12:00 PM',
    ),
  ];
}
