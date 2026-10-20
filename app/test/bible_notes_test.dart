import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';

/// Serves one passage body, shaped as the YouVersion API returns it with
/// `include_notes=true`: footnotes inline as nested `yv-n` spans.
class _Passage implements HttpClientAdapter {
  _Passage(this.html);
  final String html;
  Uri? asked;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked = options.uri;
    return ResponseBody.fromString(
      jsonEncode({'reference': 'Romans 8', 'content': html}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('footnotes from the API attach to their verse and stay out of the '
      'text', () async {
    final adapter = _Passage(
      '<div><div class="p"><span class="yv-v" v="1"></span>'
      '<span class="yv-vlbl">1</span>Therefore, there is now no condemnation '
      'for those who are in Christ Jesus.<span class="yv-n f">'
      '<span class="fr">8:1 </span><span class="ft">Some manuscripts add </span>'
      '<span class="fqa">who do not walk according to the flesh</span></span> '
      '<span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>because '
      'through Christ Jesus the law of the Spirit</div></div>',
    );
    final repo = BibleRepository(
      dio: Dio()..httpClientAdapter = adapter,
      appKey: 'test',
    );
    final passage = await repo.getPassage('ROM.8');

    expect(adapter.asked!.queryParameters['include_notes'], 'true');
    final segments = passage.blocks.single.segments;
    expect(segments.map((s) => s.verse), [1, 2]);
    expect(
      segments.first.text,
      'Therefore, there is now no condemnation for those who are in Christ '
      'Jesus.',
    );
    expect(segments.first.notes, [
      'Some manuscripts add who do not walk according to the flesh',
    ]);
    expect(segments.last.notes, isEmpty);
    expect(segments.last.text, startsWith('because'));
  });
}
