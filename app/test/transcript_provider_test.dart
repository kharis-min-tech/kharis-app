import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/player/presentation/widgets/transcript_sheet.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/transcript_provider.dart';

/// Answers every request with [status] and [body], or fails the connection.
Dio _dio({int? status, String body = '', bool offline = false}) =>
    Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (offline) {
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'offline',
                ),
              );
              return;
            }
            final response = Response<String>(
              requestOptions: options,
              statusCode: status,
              data: body,
            );
            if (status != null && status >= 400) {
              handler.reject(
                DioException.badResponse(
                  statusCode: status,
                  requestOptions: options,
                  response: response,
                ),
              );
            } else {
              handler.resolve(response);
            }
          },
        ),
      );

const _sermon = Sermon(
  id: '23052',
  title: 'Test message',
  speaker: 'David Antwi',
  audioUrl: 'https://x.test/a.mp3',
  transcriptUrl: 'https://x.test/transcripts/23052.txt',
);

Future<void> _openSheet(WidgetTester tester, Dio dio) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [transcriptDioProvider.overrideWithValue(dio)],
      child: const MaterialApp(
        home: Scaffold(body: TranscriptSheet(sermon: _sermon)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The R2 catalogue lists transcript links whose files were never uploaded;
  // that is "no transcript", not a connection problem.
  for (final status in [404, 403]) {
    testWidgets('a $status transcript file reads as no transcript, '
        'with no retry', (tester) async {
      await _openSheet(tester, _dio(status: status));
      expect(
        find.text('No transcript is available for this message.'),
        findsOneWidget,
      );
      expect(find.textContaining('connection'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });
  }

  testWidgets('an empty file reads as no transcript', (tester) async {
    await _openSheet(tester, _dio(status: 200, body: '  \n'));
    expect(
      find.text('No transcript is available for this message.'),
      findsOneWidget,
    );
  });

  testWidgets('a real connection failure still offers a retry', (tester) async {
    await _openSheet(tester, _dio(offline: true));
    expect(find.textContaining('connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a transcript that exists is shown', (tester) async {
    await _openSheet(
      tester,
      _dio(status: 200, body: '[0:00] Welcome to Kharis Church'),
    );
    expect(find.text('[0:00] Welcome to Kharis Church'), findsOneWidget);
  });
}
