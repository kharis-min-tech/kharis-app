import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';

/// New-here and testimony submissions, into the Content Studio (Supabase).
final connectRepositoryProvider = Provider<ConnectRepository>(
  (ref) => ConnectRepository(),
);

/// Testimony categories, as the website and the Studio name them.
const List<String> kTestimonyCategories = [
  'Deliverance',
  'Health/Healing',
  'Housing/Mortgage',
  'Safe Passage/Protection',
  'Other',
];

/// Longest testimony summary (`short_description`).
const int kTestimonySummaryMaxLength = 120;

/// Longest testimony text (`description`).
const int kTestimonyMaxLength = 2000;

/// A "New here?" card, as one row of the Supabase `visitors` table.
@immutable
class VisitorSubmission {
  const VisitorSubmission({
    required this.name,
    required this.email,
    required this.phone,
    required this.branchName,
    required this.firstVisitDate,
  });

  final String name;
  final String email;
  final String phone;
  final String? branchName;
  final DateTime firstVisitDate;

  /// The table has no visit-date column (id, name, email, phone,
  /// branch_name, message, created_at), so the date travels in `message`,
  /// which the branch team reads in the Studio.
  Map<String, Object?> toRow() => {
    'name': name,
    'email': email,
    'phone': phone.isEmpty ? null : phone,
    'branch_name': branchName,
    'message':
        'First visit: ${DateFormat('d MMM yyyy').format(firstVisitDate)}',
  };
}

/// A testimony, as one row of the Supabase `testimonies` table. It lands
/// unpublished; the team reviews and publishes it in the Studio.
@immutable
class TestimonySubmission {
  const TestimonySubmission({
    required this.name,
    required this.email,
    required this.phone,
    required this.branch,
    required this.category,
    required this.summary,
    required this.testimony,
    required this.anonymous,
  });

  final String name;
  final String email;
  final String phone;
  final Branch branch;
  final String? category;
  final String summary;
  final String testimony;
  final bool anonymous;

  Map<String, Object?> toRow() => {
    'name': name,
    'email': email.isEmpty ? null : email,
    'phone': phone.isEmpty ? null : phone,
    'branch_name': branch.name,
    'category': category,
    'short_description': summary,
    'description': testimony,
    'is_anonymous': anonymous,
    'is_published': false,
    'workspace': branch.group == Branch.phaseTwoGroup ? 'kp2' : 'general',
  };
}

/// Inserts rows over Supabase REST with the publishable key. Plain Dio, like
/// [ContentApi], rather than the Supabase SDK.
///
/// Rows are written with `Prefer: return=minimal`: members cannot read these
/// tables back (row-level security), so the id is generated here and
/// returned on success.
class ConnectRepository {
  ConnectRepository({Dio? dio}) : _dio = dio ?? Dio(_options);

  static final BaseOptions _options = BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  );

  final Dio _dio;

  /// Adds a visitor card. Returns the new row id; throws on any failure.
  Future<String> submitVisitor(VisitorSubmission visitor) =>
      _insert('visitors', visitor.toRow());

  /// Adds an unpublished testimony. Returns the new row id; throws on any
  /// failure.
  Future<String> submitTestimony(TestimonySubmission testimony) =>
      _insert('testimonies', testimony.toRow());

  Future<String> _insert(String table, Map<String, Object?> row) async {
    final id = _uuidV4();
    await _dio.post<void>(
      '${ApiConfig.supabaseUrl}/rest/v1/$table',
      data: {'id': id, ...row},
      options: Options(
        headers: const {
          'apikey': ApiConfig.supabasePublishableKey,
          'Authorization': 'Bearer ${ApiConfig.supabasePublishableKey}',
          'Prefer': 'return=minimal',
        },
        contentType: Headers.jsonContentType,
      ),
    );
    return id;
  }
}

final Random _random = Random.secure();

String _uuidV4() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
