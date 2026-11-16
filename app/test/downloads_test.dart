import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/features/messages/data/downloads_repository.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';

import 'support/fake_cache_service.dart';
import 'support/fake_just_audio_platform.dart';

/// Serves audio bytes, or fails, the way the test sets it up.
class _AudioHost implements HttpClientAdapter {
  /// Body sent for every request.
  Uint8List body = Uint8List.fromList(List.generate(4096, (i) => i % 251));

  /// Status sent for every request.
  int status = 200;

  /// Thrown in place of an answer (no connection).
  Object? failure;

  /// When set, the body is sent in two halves and the second waits for it.
  Completer<void>? holdSecondHalf;

  /// Completes when the first half has been handed over.
  Completer<void> firstHalfSent = Completer<void>();

  /// Raised in the middle of the body.
  Object? midStreamError;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final fail = failure;
    if (fail != null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: '$fail',
      );
    }
    final half = body.length ~/ 2;
    Stream<Uint8List> chunks() async* {
      yield Uint8List.sublistView(body, 0, half);
      if (!firstHalfSent.isCompleted) firstHalfSent.complete();
      final error = midStreamError;
      if (error != null) throw error;
      await holdSecondHalf?.future;
      yield Uint8List.sublistView(body, half);
    }

    return ResponseBody(
      chunks(),
      status,
      headers: {
        Headers.contentLengthHeader: ['${body.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeCacheService cache;
  late Directory folder;
  late _AudioHost host;
  late DateTime now;

  const sermon = Sermon(
    id: '4812',
    title: 'Grace upon grace',
    speaker: 'David Antwi',
    audioUrl: 'https://cdn.example/audio/grace-upon-grace.mp3',
    duration: Duration(minutes: 52),
  );
  const other = Sermon(
    id: 'yt_abc',
    title: 'Faith that works',
    speaker: 'David Antwi',
    audioUrl: 'https://cdn.example/audio/faith.m4a?token=1',
  );

  DownloadsRepository repository() {
    final repo = DownloadsRepository(
      cache,
      dio: Dio()..httpClientAdapter = host,
      directory: () async => folder,
      clock: () => now,
    );
    addTearDown(repo.dispose);
    return repo;
  }

  File fileOf(DownloadedMessage d) => File('${folder.path}/${d.fileName}');

  setUp(() async {
    cache = FakeCacheService();
    host = _AudioHost();
    now = DateTime(2026, 11, 11, 9);
    final root = await Directory.systemTemp.createTemp('kharis_downloads');
    folder = Directory('${root.path}/downloads');
    addTearDown(() => root.delete(recursive: true));
  });

  group('download', () {
    test('saves the audio and lists it with its size and saved date', () async {
      final repo = repository();
      expect(repo.isDownloaded(sermon.id), isFalse);

      final status = await repo.download(sermon);

      expect(status, isA<Downloaded>());
      expect(repo.isDownloaded(sermon.id), isTrue);
      final saved = repo.downloads().single;
      expect(saved.sermon.id, sermon.id);
      expect(saved.sermon.title, 'Grace upon grace');
      expect(saved.bytes, 4096);
      expect(saved.savedAt, now);
      expect(await fileOf(saved).readAsBytes(), host.body);
      expect(repo.totalBytes, 4096);
    });

    test('asks the host as a browser, as streaming does', () async {
      await repository().download(sermon);

      expect(host.requests.single.uri.toString(), sermon.audioUrl);
      expect(host.requests.single.headers['User-Agent'], kBrowserUserAgent);
    });

    test('the file keeps the recording\'s own extension', () async {
      final repo = repository();
      await repo.download(other);

      expect(repo.downloads().single.fileName, 'yt_abc.m4a');
    });

    test('an id is made safe for a file name', () {
      expect(
        DownloadsRepository.fileNameFor(
          const Sermon(
            id: '../a b/c',
            title: '',
            speaker: '',
            audioUrl: 'https://cdn.example/stream',
          ),
        ),
        '___a_b_c.mp3',
      );
    });

    test('reports progress while it runs', () async {
      final repo = repository();
      host.holdSecondHalf = Completer<void>();
      final seen = <double?>[];
      repo.changes.addListener(() {
        final status = repo.statusOf(sermon.id);
        if (status is Downloading) seen.add(status.fraction);
      });

      final done = repo.download(sermon);
      await host.firstHalfSent.future;
      await pumpEventQueue();

      final midway = repo.statusOf(sermon.id);
      expect(midway, isA<Downloading>());
      expect((midway as Downloading).total, 4096);
      expect(midway.fraction, 0.5);

      host.holdSecondHalf!.complete();
      await done;

      expect(seen, containsAllInOrder(<double?>[0.5, 1.0]));
      expect(repo.statusOf(sermon.id), isA<Downloaded>());
    });

    test('asking again while it runs joins the same download', () async {
      final repo = repository();
      host.holdSecondHalf = Completer<void>();

      final first = repo.download(sermon);
      final second = repo.download(sermon);
      await host.firstHalfSent.future;
      host.holdSecondHalf!.complete();
      await Future.wait([first, second]);

      expect(host.requests, hasLength(1));
      expect(repo.downloads(), hasLength(1));
    });

    test('a saved message is not fetched again', () async {
      final repo = repository();
      await repo.download(sermon);

      expect(await repo.download(sermon), isA<Downloaded>());
      expect(host.requests, hasLength(1));
    });

    test('the list is most recently saved first', () async {
      final repo = repository();
      await repo.download(sermon);
      now = now.add(const Duration(hours: 2));
      await repo.download(other);

      expect(
        [for (final d in repo.downloads()) d.sermon.id],
        ['yt_abc', '4812'],
      );
    });
  });

  group('cancel and delete', () {
    test('cancel stops the download and leaves nothing behind', () async {
      final repo = repository();
      host.holdSecondHalf = Completer<void>();

      final done = repo.download(sermon);
      await host.firstHalfSent.future;
      await pumpEventQueue();
      repo.cancel(sermon.id);

      expect(await done, isA<NotDownloaded>());
      expect(repo.statusOf(sermon.id), isA<NotDownloaded>());
      expect(repo.isDownloaded(sermon.id), isFalse);
      expect(folder.listSync(), isEmpty);
    });

    test('delete removes the file and the entry', () async {
      final repo = repository();
      await repo.download(sermon);
      final file = fileOf(repo.downloads().single);

      await repo.delete(sermon.id);

      expect(repo.isDownloaded(sermon.id), isFalse);
      expect(repo.downloads(), isEmpty);
      expect(file.existsSync(), isFalse);
      expect(repo.totalBytes, 0);
    });

    test('delete during a download stops it', () async {
      final repo = repository();
      host.holdSecondHalf = Completer<void>();

      final done = repo.download(sermon);
      await host.firstHalfSent.future;
      await repo.delete(sermon.id);

      expect(await done, isA<NotDownloaded>());
      expect(folder.listSync(), isEmpty);
    });

    test('deleting a message that is not saved does nothing', () async {
      final repo = repository();

      await expectLater(repo.delete('nope'), completes);
    });
  });

  group('failures', () {
    Future<DownloadFailureReason> failWith(
      DownloadsRepository repo, [
      Sermon message = sermon,
    ]) async {
      final status = await repo.download(message);
      expect(status, isA<DownloadFailed>());
      return (status as DownloadFailed).reason;
    }

    test('a full phone is reported as no space', () async {
      final repo = repository();
      host.midStreamError = const FileSystemException(
        'write failed',
        '/x',
        OSError('No space left on device', 28),
      );

      expect(await failWith(repo), DownloadFailureReason.noSpace);
      expect(repo.isDownloaded(sermon.id), isFalse);
      expect(folder.listSync(), isEmpty, reason: 'the partial file is removed');
    });

    test('another write error is reported as storage', () async {
      final repo = repository();
      host.midStreamError = const FileSystemException(
        'write failed',
        '/x',
        OSError('Input/output error', 5),
      );

      expect(await failWith(repo), DownloadFailureReason.storage);
    });

    test('no connection is reported as connection', () async {
      final repo = repository();
      host.failure = const SocketException('Failed host lookup');

      expect(await failWith(repo), DownloadFailureReason.connection);
    });

    test('a refusal by the server is reported as server', () async {
      final repo = repository();
      host.status = 404;

      expect(await failWith(repo), DownloadFailureReason.server);
      expect(folder.listSync(), isEmpty);
    });

    test('a message with no audio is reported as no audio', () async {
      final repo = repository();
      const videoOnly = Sermon(
        id: 'v1',
        title: 'Video only',
        speaker: '',
        audioUrl: '',
        videoId: 'abc',
      );

      expect(await failWith(repo, videoOnly), DownloadFailureReason.noAudio);
      expect(host.requests, isEmpty);
    });

    test('the failure shows until it is cleared or retried', () async {
      final repo = repository();
      host.failure = const SocketException('offline');
      await repo.download(sermon);
      expect(repo.statusOf(sermon.id), isA<DownloadFailed>());

      repo.clearFailure(sermon.id);
      expect(repo.statusOf(sermon.id), isA<NotDownloaded>());

      host.failure = const SocketException('offline');
      await repo.download(sermon);
      host.failure = null;
      expect(await repo.download(sermon), isA<Downloaded>());
      expect(repo.statusOf(sermon.id), isA<Downloaded>());
    });

    test('with no app storage a download fails and nothing throws', () async {
      final repo = DownloadsRepository(
        cache,
        dio: Dio()..httpClientAdapter = host,
        directory: () async => throw const FileSystemException('no storage'),
      );
      addTearDown(repo.dispose);

      await expectLater(repo.ready, completes);
      expect(await failWith(repo), DownloadFailureReason.storage);
    });
  });

  group('restart', () {
    test('saved messages are listed again', () async {
      await repository().download(sermon);

      final second = repository();
      await second.ready;

      expect(second.isDownloaded(sermon.id), isTrue);
      expect(second.downloads().single.sermon.title, 'Grace upon grace');
      expect(second.downloads().single.sermon.duration?.inMinutes, 52);
    });

    test('an entry whose file is gone is dropped', () async {
      final first = repository();
      await first.download(sermon);
      fileOf(first.downloads().single).deleteSync();

      final second = repository();
      await second.ready;

      expect(second.isDownloaded(sermon.id), isFalse);
      expect(second.downloads(), isEmpty);
    });

    test('a partial file left by a closed app is removed', () async {
      folder.createSync(recursive: true);
      final part = File('${folder.path}/4812.mp3.part')..writeAsBytesSync([1]);

      await repository().ready;

      expect(part.existsSync(), isFalse);
    });

    test('unreadable saved data reads as nothing saved', () async {
      cache.preferences[DownloadsRepository.indexKey] = '{not json';

      final repo = repository();
      await repo.ready;

      expect(repo.downloads(), isEmpty);
    });
  });

  group('playing a saved message', () {
    test('localAudioUri is the saved file', () async {
      final repo = repository();
      expect(repo.localAudioUri(sermon), isNull);

      await repo.download(sermon);

      final uri = repo.localAudioUri(sermon)!;
      expect(uri.scheme, 'file');
      expect(File.fromUri(uri).readAsBytesSync(), host.body);
    });

    test('a message that is not saved streams', () async {
      final repo = repository();
      await repo.download(sermon);

      expect(repo.localAudioUri(other), isNull);
    });

    test(
      'a message whose recording was replaced streams the new one',
      () async {
        final repo = repository();
        await repo.download(sermon);
        const replaced = Sermon(
          id: '4812',
          title: 'Grace upon grace',
          speaker: 'David Antwi',
          audioUrl: 'https://cdn.example/audio/grace-upon-grace-v2.mp3',
        );

        expect(repo.localAudioUri(replaced), isNull);
      },
    );

    test('a saved file that has since gone missing streams', () async {
      final repo = repository();
      await repo.download(sermon);
      fileOf(repo.downloads().single).deleteSync();

      expect(repo.localAudioUri(sermon), isNull);
    });

    test(
      'the same recording under another id plays from the saved file',
      () async {
        final repo = repository();
        await repo.download(sermon);
        const twin = Sermon(
          id: 'yt_twin',
          title: 'Grace upon grace',
          speaker: 'David Antwi',
          audioUrl: 'https://cdn.example/audio/grace-upon-grace.mp3',
          videoId: 'twin',
        );

        expect(repo.localAudioUri(twin), isNotNull);
      },
    );
  });

  group('the audio player', () {
    late FakeJustAudioPlatform platform;

    /// The address the engine was last asked to load for the first item.
    String loadedUri() {
      final source = platform.player!.loads.last.audioSourceMessage;
      final first = source is ConcatenatingAudioSourceMessage
          ? source.children.first
          : source;
      return (first as UriAudioSourceMessage).uri;
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      platform = FakeJustAudioPlatform.install();
    });

    test('plays the saved file when the message is downloaded', () async {
      final repo = repository();
      await repo.download(sermon);
      final service = AudioPlayerService(cache, localAudio: repo.localAudioUri);
      addTearDown(service.dispose);

      await service.play(sermon);

      expect(loadedUri(), repo.localAudioUri(sermon).toString());
      expect(loadedUri(), startsWith('file://'));
    });

    test('streams a message that is not downloaded', () async {
      final repo = repository();
      await repo.ready;
      final service = AudioPlayerService(cache, localAudio: repo.localAudioUri);
      addTearDown(service.dispose);

      await service.play(sermon);

      expect(loadedUri(), sermon.audioUrl);
    });

    test('streams as before when no downloads are wired in', () async {
      final service = AudioPlayerService(cache);
      addTearDown(service.dispose);

      await service.play(sermon);

      expect(loadedUri(), sermon.audioUrl);
    });

    test('in a queue, only the downloaded message plays from disk', () async {
      final repo = repository();
      await repo.download(other);
      final service = AudioPlayerService(cache, localAudio: repo.localAudioUri);
      addTearDown(service.dispose);

      await service.play(sermon, queue: const [sermon, other]);

      final source =
          platform.player!.loads.last.audioSourceMessage
              as ConcatenatingAudioSourceMessage;
      final uris = [
        for (final child in source.children)
          (child as UriAudioSourceMessage).uri,
      ];
      expect(uris.first, sermon.audioUrl);
      expect(uris.last, startsWith('file://'));
    });
  });

  group('providers', () {
    test('status, list and isDownloaded follow the repository', () async {
      final repo = repository();
      final c = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(cache),
          downloadsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      final status = c.listen(downloadStatusProvider(sermon.id), (_, _) {});
      final isSaved = c.listen(isDownloadedProvider(sermon.id), (_, _) {});
      addTearDown(status.close);
      addTearDown(isSaved.close);
      expect(status.read(), isA<NotDownloaded>());
      expect(isSaved.read(), isFalse);
      expect(c.read(downloadsProvider), isEmpty);

      await repo.download(sermon);

      expect(status.read(), isA<Downloaded>());
      expect(isSaved.read(), isTrue);
      expect(c.read(downloadsProvider).single.sermon.id, sermon.id);

      await repo.delete(sermon.id);

      expect(status.read(), isA<NotDownloaded>());
      expect(isSaved.read(), isFalse);
      expect(c.read(downloadsProvider), isEmpty);
    });
  });
}
