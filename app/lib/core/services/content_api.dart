import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/api_config.dart';
import 'cache_service.dart';

/// Reads the public Kharis Content Studio tables over Supabase REST
/// (`GET {supabaseUrl}/rest/v1/{table}`) with the publishable key.
///
/// Plain Dio rather than the Supabase SDK: the app only ever reads a handful
/// of public tables, and the SDK would add realtime, auth and storage code to
/// every install.
///
/// The last good response of each table is kept in [CacheService], so a cold
/// launch without a connection still shows the last known branches, events
/// and announcements. Every table is read with one fixed query, so one cache
/// entry per table is exact.
class ContentApi {
  ContentApi({Dio? dio, this._cache}) : _dio = dio ?? Dio(_options);

  static final BaseOptions _options = BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  );

  static const Map<String, String> _headers = {
    'apikey': ApiConfig.supabasePublishableKey,
    'Authorization': 'Bearer ${ApiConfig.supabasePublishableKey}',
    'Accept': 'application/json',
  };

  final Dio _dio;
  final CacheService? _cache;

  static String _cacheKey(String table) => 'content_cache.$table';

  /// Rows of [table] from the network. Throws when the request fails or the
  /// body is not a JSON array; a success replaces the cached copy.
  Future<List<Map<String, dynamic>>> fetch(
    String table, {
    Map<String, String> query = const {},
  }) async {
    final res = await _dio.get<Object?>(
      '${ApiConfig.supabaseUrl}/rest/v1/$table',
      queryParameters: {'select': '*', ...query},
      options: Options(headers: _headers, responseType: ResponseType.plain),
    );
    final body = res.data;
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is! List) {
      throw FormatException('Expected a JSON array from $table');
    }
    final rows = decoded.whereType<Map<String, dynamic>>().toList();
    _write(table, rows);
    return rows;
  }

  /// The last good rows of [table] saved on this device, or null.
  List<Map<String, dynamic>>? cached(String table) {
    final cache = _cache;
    if (cache == null) return null;
    try {
      final raw = cache.getPreference<String?>(_cacheKey(table), null);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      // A corrupt entry is a cold start, not a failure.
      return null;
    }
  }

  /// [fetch], falling back to the cached rows when the network fails.
  /// Rethrows only when there is no cached copy either.
  Future<List<Map<String, dynamic>>> load(
    String table, {
    Map<String, String> query = const {},
  }) async {
    try {
      return await fetch(table, query: query);
    } catch (_) {
      final saved = cached(table);
      if (saved != null) return saved;
      rethrow;
    }
  }

  /// The cached rows first (when there are any), then the network's. A
  /// network failure ends the stream quietly when the cached rows are already
  /// on screen, and surfaces as an error when nothing is.
  Stream<List<Map<String, dynamic>>> watch(
    String table, {
    Map<String, String> query = const {},
  }) async* {
    final saved = cached(table);
    if (saved != null) yield saved;
    try {
      yield await fetch(table, query: query);
    } catch (_) {
      if (saved == null) rethrow;
    }
  }

  void _write(String table, List<Map<String, dynamic>> rows) {
    try {
      _cache?.cachePreference(_cacheKey(table), jsonEncode(rows));
    } catch (_) {
      // Caching is best effort; the fresh rows are still returned.
    }
  }
}
