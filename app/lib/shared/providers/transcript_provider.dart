import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/player/domain/transcript.dart';

/// HTTP client for transcript files; overridden in tests.
final transcriptDioProvider = Provider<Dio>(
  (ref) => Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))),
);

/// Fetches one sermon's transcript on demand and splits it at its timestamp
/// markers (see [Transcript.parse]) once, rather than on every rebuild.
///
/// Deliberately lazy: [Sermon.transcriptUrl] is already known once the
/// catalogue loads, but the text itself (tens of KB per sermon) is only
/// fetched when a member actually opens the transcript view — not as part
/// of loading the library.
///
/// `null` means the message has no transcript after all: the R2 catalogue
/// lists a transcript link for messages whose file was never uploaded (404),
/// and some files are empty (or hold nothing but markers). Only real
/// failures (no connection, timeouts, server errors) surface as errors, so
/// the sheet never blames the member's connection for a file that does not
/// exist.
///
/// `autoDispose` drops the cached transcript once nothing is reading it (the
/// sheet that requested it closed), rather than keeping every transcript a
/// member has ever opened this session in memory.
final transcriptProvider = FutureProvider.autoDispose
    .family<Transcript?, String>((ref, url) async {
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
      final transcript = Transcript.parse(res.data ?? '');
      return transcript.segments.isEmpty ? null : transcript;
    });
