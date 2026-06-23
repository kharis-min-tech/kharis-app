import 'package:dio/dio.dart';

/// Fetches [url] as plain text using Dio (mobile, desktop).
Future<String> fetchFeed(String url) async {
  final response = await Dio().get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  return response.data ?? '';
}
