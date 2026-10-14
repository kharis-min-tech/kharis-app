import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// HTTP client for transcript files; overridden in tests.
final transcriptDioProvider = Provider<Dio>((ref) => Dio());

/// Fetches one sermon's transcript text on demand.
///
/// Deliberately lazy: [Sermon.transcriptUrl] is already known once the
/// catalogue loads, but the text itself (tens of KB per sermon) is only
/// fetched when a member actually opens the transcript view — not as part
/// of loading the library.
///
/// `null` means the message has no transcript after all: the R2 catalogue
/// lists a transcript link for messages whose file was never uploaded (404),
/// and some files are empty. Only real failures (no connection, timeouts,
/// server errors) surface as errors, so the sheet never blames the member's
/// connection for a file that does not exist.
///
/// `autoDispose` drops the cached text once nothing is reading it (the sheet
/// that requested it closed), rather than keeping every transcript a member
/// has ever opened this session in memory.
final transcriptProvider = FutureProvider.autoDispose.family<String?, String>((
  ref,
  url,
) async {
  final Response<String> res;
  try {
    res = await ref
        .watch(transcriptDioProvider)
        .get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status == 404 || status == 403) return null;
    rethrow;
  }
  final text = res.data?.trim() ?? '';
  return text.isEmpty ? null : text;
});
