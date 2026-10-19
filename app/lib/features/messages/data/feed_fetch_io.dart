import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Connect/receive limits so a silent connection fails into the caller's
/// fallbacks instead of hanging.
@visibleForTesting
final feedDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ),
);

/// Overall deadline for one feed request, including a slowly trickling body.
/// Settable so tests need not wait it out.
@visibleForTesting
Duration feedFetchDeadline = const Duration(seconds: 30);

/// Fetches [url] as plain text using Dio (mobile, desktop).
Future<String> fetchFeed(String url) async {
  final response = await feedDio
      .get<String>(url, options: Options(responseType: ResponseType.plain))
      .timeout(feedFetchDeadline);
  return response.data ?? '';
}
