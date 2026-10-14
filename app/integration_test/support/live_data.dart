// Expectations read from the live sources at run time, never pinned in the
// test: the Content Studio (Supabase REST, public key), the sermon API, the
// R2 message catalogue and YouVersion. Read independently of the app's own
// repositories so a mapping bug in the app cannot hide itself.

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/core/constants/http_constants.dart';

final _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 40),
  ),
);

Future<List<Map<String, dynamic>>> studioRows(
  String table, [
  Map<String, String> query = const {},
]) async {
  final res = await _dio.get<List<dynamic>>(
    '${ApiConfig.supabaseUrl}/rest/v1/$table',
    queryParameters: {'select': '*', ...query},
    options: Options(
      headers: {
        'apikey': ApiConfig.supabasePublishableKey,
        'Authorization': 'Bearer ${ApiConfig.supabasePublishableKey}',
      },
    ),
  );
  return [for (final r in res.data ?? const []) Map<String, dynamic>.from(r)];
}

/// A Studio branch with its active services, as the Studio stores them.
class StudioBranch {
  StudioBranch(this.row, this.services);

  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> services;

  String get uuid => '${row['id']}';
  String get name => '${row['name']}'.trim();
  String get groupRaw => '${row['group'] ?? ''}';

  /// Same rule as the Studio's "Kharis" / "Kharis Phase 2" groups.
  bool get isPhaseTwo {
    final g = groupRaw.toLowerCase();
    return g.contains('phase 2') || g.contains('phase two') || g.contains('kp2');
  }

  /// Name as the branch picker tile shows it.
  String get tileName => name.startsWith('KP2 ') ? name.substring(4) : name;

  @override
  String toString() => name;
}

Future<List<StudioBranch>> studioBranches() async {
  final results = await Future.wait([
    studioRows('branches', {'is_active': 'eq.true', 'order': 'sort_order'}),
    studioRows('services', {'is_active': 'eq.true'}),
  ]);
  final services = results[1];
  return [
    for (final b in results[0])
      StudioBranch(b, [
        for (final s in services)
          if ('${s['branch_id']}' == '${b['id']}') s,
      ]),
  ];
}

/// "14:00:00" -> "2:00 PM"; null when unusable.
String? formatClock(Object? raw) {
  final s = '${raw ?? ''}'.trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) return null;
  final t = DateTime(2000, 1, 1, int.parse(m.group(1)!), int.parse(m.group(2)!));
  return DateFormat('h:mm a').format(t);
}

/// "Sunday · 10:00 AM – 12:00 PM" for a Studio service row.
String? serviceWhen(Map<String, dynamic> s) {
  final start = formatClock(s['start_time']);
  final end = formatClock(s['end_time']);
  final time = start == null
      ? end
      : end == null
      ? start
      : '$start \u2013 $end';
  final day = '${s['day'] ?? ''}'.trim();
  final parts = [if (day.isNotEmpty) day, ?time];
  return parts.isEmpty ? null : parts.join(' \u00b7 ');
}

/// A Studio event row with the fields the journeys compare.
class StudioEvent {
  StudioEvent(this.row);

  final Map<String, dynamic> row;

  String get id => '${row['id']}';
  String get title => '${row['title'] ?? ''}'.trim();
  String? get branch {
    final b = '${row['branch_name'] ?? ''}'.trim();
    return b.isEmpty ? null : b;
  }

  bool get weekly => '${row['recurrence'] ?? ''}'.toLowerCase() == 'weekly';
  List<int> get days => [
    for (final d in (row['recurrence_days'] as List? ?? const [])) d as int,
  ]..sort();

  DateTime get start => DateTime.parse('${row['start_time']}').toLocal();
  DateTime? get end {
    final raw = row['end_time'];
    return raw == null ? null : DateTime.tryParse('$raw')?.toLocal();
  }

  DateTime? get until {
    final raw = '${row['recurrence_until'] ?? ''}'.trim();
    return raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  bool visibleTo(String? memberBranch) =>
      memberBranch == null || branch == null || branch == memberBranch;

  /// One-off events that have finished. Weekly events are never past until
  /// their `recurrence_until` has gone by.
  bool isPast(DateTime now) {
    if (weekly) {
      final u = until;
      return u != null && u.isBefore(DateTime(now.year, now.month, now.day));
    }
    return (end ?? start).isBefore(now);
  }

  static const _weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  /// What the Studio means for a weekly event: "Every Sunday · 9:00 AM".
  String get everyLabel {
    final names = [for (final d in days) _weekdays[d]];
    final joined = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return 'Every $joined \u00b7 ${DateFormat('h:mm a').format(start)}';
  }

  @override
  String toString() => '$title${weekly ? ' (weekly)' : ''}';
}

Future<List<StudioEvent>> studioEvents() async =>
    [for (final r in await studioRows('events')) StudioEvent(r)];

/// Studio announcements the app treats as published.
Future<List<Map<String, dynamic>>> studioNews() async {
  final rows = await studioRows('news');
  return [
    for (final r in rows)
      if (r['status'] == null || r['status'] == 'published' || r['status'] == 'live')
        if (r['is_published'] != false && r['published'] != false) r,
  ];
}

/// Total the sermon API reports (the archive the app must hydrate to).
Future<int> sermonApiCount() async {
  final res = await _dio.get<Map<String, dynamic>>(
    '${ApiConfig.sermonApiDirectBase}sermons/',
    options: Options(headers: {'User-Agent': kBrowserUserAgent}),
  );
  return (res.data!['count'] as num).toInt();
}

/// The R2 message catalogue (ids match the app's sermon ids).
Future<List<Map<String, dynamic>>> r2Messages() async {
  final res = await _dio.get<dynamic>(kR2MessagesUrl);
  final data = res.data is Map ? res.data as Map : const {};
  return [
    for (final m in (data['messages'] as List? ?? const []))
      Map<String, dynamic>.from(m as Map),
  ];
}

Future<String> fetchText(String url) async {
  final res = await _dio.get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  return res.data ?? '';
}

/// English Bible versions YouVersion offers this app key.
Future<List<({int id, String abbreviation})>> youVersionBibles() async {
  const key = String.fromEnvironment('YOUVERSION_API_KEY');
  final res = await _dio.get<Map<String, dynamic>>(
    'https://api.youversion.com/v1/bibles',
    queryParameters: {'language_ranges[]': 'en', 'page_size': 50},
    options: Options(headers: {'x-yvp-app-key': key}),
  );
  return [
    for (final b in (res.data?['data'] as List? ?? const []))
      (id: (b['id'] as num).toInt(), abbreviation: '${b['abbreviation']}'),
  ];
}

/// Books (USFM id, title, chapter count) of [bibleId] on YouVersion.
Future<List<({String usfm, String title, int chapters})>> youVersionBooks(
  int bibleId,
) async {
  const key = String.fromEnvironment('YOUVERSION_API_KEY');
  final res = await _dio.get<Map<String, dynamic>>(
    'https://api.youversion.com/v1/bibles/$bibleId/books',
    options: Options(headers: {'x-yvp-app-key': key}),
  );
  return [
    for (final b in (res.data?['data'] as List? ?? const []))
      (
        usfm: '${b['id']}',
        title: '${b['title']}',
        chapters: (b['chapters'] as List? ?? const []).length,
      ),
  ];
}

/// Deterministic per-run random source (seeded by the run date).
Random seeded(int seed, String salt) => Random(seed ^ salt.hashCode);

T pick<T>(Random r, List<T> items) => items[r.nextInt(items.length)];
