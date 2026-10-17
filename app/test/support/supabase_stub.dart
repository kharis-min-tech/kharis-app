import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/core/services/content_api.dart';

/// Serves canned Supabase REST rows per table (`/rest/v1/<table>`) and
/// records every request. A table missing from [tables] (or every table
/// while [offline]) fails like a dropped connection; while [rlsDenied],
/// every request gets PostgREST's row-level-security 401 (code 42501).
class SupabaseStub implements HttpClientAdapter {
  SupabaseStub(this.tables);

  final Map<String, List<Map<String, dynamic>>> tables;
  final List<RequestOptions> requests = [];
  bool offline = false;
  bool rlsDenied = false;

  /// A [ContentApi] served by this stub.
  ContentApi api({CacheService? cache}) =>
      ContentApi(dio: Dio()..httpClientAdapter = this, cache: cache);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final table = options.uri.pathSegments.last;
    final rows = tables[table];
    if (offline || rows == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    if (rlsDenied) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': '42501',
          'message':
              'new row violates row-level security policy for table "$table"',
        }),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(rows),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
