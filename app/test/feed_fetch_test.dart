import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/messages/data/feed_fetch_io.dart';
import 'package:kharis_app/shared/providers/transcript_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('feed requests carry connect and receive timeouts', () {
    expect(feedDio.options.connectTimeout, const Duration(seconds: 10));
    expect(feedDio.options.receiveTimeout, const Duration(seconds: 20));
  });

  test('a feed that never answers fails by the overall deadline', () async {
    final saved = feedFetchDeadline;
    // Never resolves: a connection that was accepted, then went silent.
    final stall = InterceptorsWrapper(onRequest: (_, _) {});
    feedDio.interceptors.add(stall);
    feedFetchDeadline = const Duration(milliseconds: 50);
    addTearDown(() {
      feedDio.interceptors.remove(stall);
      feedFetchDeadline = saved;
    });

    await expectLater(
      fetchFeed('https://feed.test/videos.xml'),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('transcript requests carry a connect timeout', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(transcriptDioProvider).options.connectTimeout,
      const Duration(seconds: 10),
    );
  });
}
