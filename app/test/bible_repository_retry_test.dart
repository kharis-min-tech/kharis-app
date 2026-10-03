import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/bible_repository.dart';

/// Answers passage requests from a script: each entry is either an HTTP
/// status to return or `null` for a connection that drops before replying.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final List<int?> script;
  int calls = 0;

  static const _passage =
      '{"reference":"2 Corinthians 13","content":"<div class=\\"p\\">'
      '<span class=\\"yv-vlbl\\">1</span>This will be my third visit.</div>"}';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final step = script[calls++];
    if (step == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'connection reset',
      );
    }
    return ResponseBody.fromString(
      step == 200 ? _passage : '{"message":"not found"}',
      step,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

BibleRepository _repo(_ScriptedAdapter adapter) =>
    BibleRepository(dio: Dio()..httpClientAdapter = adapter, appKey: 'test');

void main() {
  setUp(() => BibleRepository.retryDelay = Duration.zero);

  test('a dropped connection is retried once and the passage loads', () async {
    final adapter = _ScriptedAdapter([null, 200]);
    final passage = await _repo(adapter).getPassage('2CO.13');

    expect(adapter.calls, 2);
    expect(passage.reference, '2 Corinthians 13');
    expect(passage.blocks, isNotEmpty);
  });

  test('a real 404 is reported at once, not retried', () async {
    final adapter = _ScriptedAdapter([404, 200]);
    await expectLater(
      _repo(adapter).getPassage('2CO.17'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
    expect(adapter.calls, 1);
  });

  test('two dropped connections in a row surface the error', () async {
    final adapter = _ScriptedAdapter([null, null]);
    await expectLater(
      _repo(adapter).getPassage('2CO.13'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 2);
  });
}
