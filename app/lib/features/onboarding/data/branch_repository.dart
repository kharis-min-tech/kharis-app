import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Stream<List<Branch>> watchBranches() async* {
    try {
      yield* _firestore.collection('branches').orderBy('order').snapshots().map(
        (snap) {
          final list = snap.docs.map((d) => _map(d.id, d.data())).toList();
          return list.isEmpty ? seedBranches : list;
        },
      );
    } catch (_) {
      yield seedBranches;
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
  }) {
    return _firestore
        .collection('branches')
        .add(
          _data(
            name: name,
            subtitle: subtitle,
            gradientStart: gradientStart,
            gradientEnd: gradientEnd,
            imageUrl: imageUrl,
            order: order,
            address: address,
            meetingDays: meetingDays,
            meetingTime: meetingTime,
          ),
        );
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
  }) {
    return _firestore
        .collection('branches')
        .doc(id)
        .update(
          _data(
            name: name,
            subtitle: subtitle,
            gradientStart: gradientStart,
            gradientEnd: gradientEnd,
            imageUrl: imageUrl,
            order: order,
            address: address,
            meetingDays: meetingDays,
            meetingTime: meetingTime,
          ),
        );
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
  }) => {
    'name': name,
    'subtitle': subtitle,
    'gradientStart': Branch.toHex(gradientStart),
    'gradientEnd': Branch.toHex(gradientEnd),
    'imageUrl': imageUrl,
    'order': order,
    'address': address,
    'meetingDays': meetingDays,
    'meetingTime': meetingTime,
  };

  Branch _map(String id, Map<String, dynamic> data) => Branch(
    id: id,
    name: data['name'] as String? ?? '',
    subtitle: data['subtitle'] as String? ?? '',
    gradientStart: Branch.parseHex(
      data['gradientStart'] as String?,
      const Color(0xFF3B2A6B),
    ),
    gradientEnd: Branch.parseHex(
      data['gradientEnd'] as String?,
      const Color(0xFF7C3AED),
    ),
    imageUrl: data['imageUrl'] as String?,
    order: (data['order'] as num?)?.toInt() ?? 0,
    address: data['address'] as String?,
    meetingDays: data['meetingDays'] as String?,
    meetingTime: data['meetingTime'] as String?,
  );

  /// Built-in branches, used to seed Firestore and as an offline fallback.
  /// Landmark images are open-licensed (Wikimedia Commons).
  static const _thumb = 'https://upload.wikimedia.org/wikipedia/commons/thumb';

  static final List<Branch> seedBranches = [
    Branch(
      id: 'london',
      name: 'Kharis London',
      subtitle: 'United Kingdom · Main Campus',
      gradientStart: const Color(0xFF3B2A6B),
      gradientEnd: const Color(0xFF7C3AED),
      imageUrl:
          '$_thumb/4/43/Elizabeth_Tower%2C_June_2022.jpg/330px-Elizabeth_Tower%2C_June_2022.jpg',
      order: 0,
      address: 'London, United Kingdom',
      meetingDays: 'Sundays',
      meetingTime: '10:00 AM',
    ),
    Branch(
      id: 'manchester',
      name: 'Kharis Manchester',
      subtitle: 'United Kingdom · North Branch',
      gradientStart: const Color(0xFF4A21AE),
      gradientEnd: const Color(0xFF6B34FA),
      imageUrl:
          '$_thumb/7/7f/Manchester_Town_Hall_from_Lloyd_St.jpg/330px-Manchester_Town_Hall_from_Lloyd_St.jpg',
      order: 1,
      address: 'Manchester, United Kingdom',
      meetingDays: 'Sundays',
      meetingTime: '10:30 AM',
    ),
    Branch(
      id: 'birmingham',
      name: 'Kharis Birmingham',
      subtitle: 'United Kingdom · Midlands',
      gradientStart: const Color(0xFF5B1F4F),
      gradientEnd: const Color(0xFFC0297F),
      imageUrl:
          '$_thumb/e/ec/Selfridges_Building%2C_Birmingham_%282012%29.jpg/330px-Selfridges_Building%2C_Birmingham_%282012%29.jpg',
      order: 2,
    ),
    Branch(
      id: 'reading',
      name: 'Kharis Reading',
      subtitle: 'United Kingdom · South East',
      gradientStart: const Color(0xFFC2410C),
      gradientEnd: const Color(0xFFFD7F20),
      imageUrl:
          '$_thumb/c/c4/The_Blade%2C_Abbey_Square%2C_Reading.jpg/330px-The_Blade%2C_Abbey_Square%2C_Reading.jpg',
      order: 3,
    ),
    Branch(
      id: 'chatham',
      name: 'Kharis Chatham',
      subtitle: 'United Kingdom · Kent',
      gradientStart: const Color(0xFFC2410C),
      gradientEnd: const Color(0xFFFB923C),
      imageUrl:
          '$_thumb/9/9c/The_Commissioner%27s_House%2C_Chatham_Historic_Dockyard_-_geograph.org.uk_-_3473286.jpg/330px-The_Commissioner%27s_House%2C_Chatham_Historic_Dockyard_-_geograph.org.uk_-_3473286.jpg',
      order: 4,
    ),
    Branch(
      id: 'croydon',
      name: 'Kharis Croydon',
      subtitle: 'United Kingdom · South London',
      gradientStart: const Color(0xFF9F1239),
      gradientEnd: const Color(0xFFFB7185),
      imageUrl:
          '$_thumb/0/0f/No.1_Croydon_%28NLA_Tower%29_November_2023.jpg/330px-No.1_Croydon_%28NLA_Tower%29_November_2023.jpg',
      order: 5,
    ),
    Branch(
      id: 'medway',
      name: 'Kharis Medway',
      subtitle: 'United Kingdom · Kent',
      gradientStart: const Color(0xFF800654),
      gradientEnd: const Color(0xFFC0297F),
      imageUrl:
          '$_thumb/3/3c/Rochester_Castle_from_main_approach.jpg/330px-Rochester_Castle_from_main_approach.jpg',
      order: 6,
    ),
    Branch(
      id: 'accra',
      name: 'Kharis Accra',
      subtitle: 'Ghana · International Campus',
      gradientStart: const Color(0xFF7A3B0A),
      gradientEnd: const Color(0xFFFD7F20),
      imageUrl:
          '$_thumb/4/4a/Independence_Arch_-_Accra%2C_Ghana1.jpg/330px-Independence_Arch_-_Accra%2C_Ghana1.jpg',
      order: 7,
      address: 'Accra, Ghana',
      meetingDays: 'Sundays',
      meetingTime: '9:00 AM',
    ),
    Branch(
      id: 'freetown',
      name: 'Kharis Freetown',
      subtitle: 'Sierra Leone · West Africa',
      gradientStart: const Color(0xFF6B34FA),
      gradientEnd: const Color(0xFF9D6BFF),
      imageUrl:
          '$_thumb/c/c3/St._George%27s_Cathedral_Freetown.jpg/330px-St._George%27s_Cathedral_Freetown.jpg',
      order: 8,
    ),
  ];
}
