import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/features/player/data/sermon_localization.dart';
import 'package:kharis_app/shared/models/sermon.dart';

final sermonLocalizationDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

/// Published separately from the imported catalogue so an import cannot erase dubs.
final sermonLanguageTracksProvider = FutureProvider.autoDispose
    .family<List<SermonLanguageTrack>, Sermon>((ref, sermon) async {
      if (!sermon.hasAudio) return const [];
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final response = await ref
          .watch(sermonLocalizationDioProvider)
          .get<Object?>(
            '$kR2BucketBaseUrl/localizations/${Uri.encodeComponent(sermon.id)}.json',
            cancelToken: token,
            options: Options(validateStatus: (s) => s == 200 || s == 404),
          );
      if (response.statusCode == 404) return const [];
      return SermonLanguageTrack.fromManifest(
        response.data,
        sermonId: sermon.id,
        sourceAudioUrl: sermon.audioUrl,
      );
    });

final sermonCaptionsProvider = FutureProvider.autoDispose
    .family<List<SermonCaption>, String>((ref, url) async {
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final response = await ref
          .watch(sermonLocalizationDioProvider)
          .get<String>(
            url,
            cancelToken: token,
            options: Options(responseType: ResponseType.plain),
          );
      return parseSermonCaptions(response.data ?? '');
    });
