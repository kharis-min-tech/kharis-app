import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fetches one sermon's transcript text on demand.
///
/// Deliberately lazy: [Sermon.transcriptUrl] is already known once the
/// catalogue loads, but the text itself (tens of KB per sermon) is only
/// fetched when a member actually opens the transcript view — not as part
/// of loading the library.
///
/// `autoDispose` drops the cached text once nothing is reading it (the sheet
/// that requested it closed), rather than keeping every transcript a member
/// has ever opened this session in memory.
final transcriptProvider =
    FutureProvider.autoDispose.family<String, String>((ref, url) async {
  final dio = Dio();
  final res = await dio.get<String>(
    url,
    options: Options(
      responseType: ResponseType.plain,
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final text = res.data?.trim() ?? '';
  if (text.isEmpty) throw StateError('empty transcript');
  return text;
});
