import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/shared/models/sermon.dart';

void main() {
  Sermon video({
    Duration? duration,
    String title = 'A message',
    String? videoId = 'abc123',
  }) => Sermon(
    id: 'x',
    title: title,
    speaker: 'Kharis Church',
    audioUrl: '',
    videoId: videoId,
    duration: duration,
  );

  test('a 22-second video is a Short', () {
    expect(video(duration: const Duration(seconds: 22)).isShortClip, isTrue);
  });

  test('a full-length video is not a Short', () {
    expect(video(duration: const Duration(minutes: 45)).isShortClip, isFalse);
  });

  test('a #shorts tag marks a Short whatever its length', () {
    expect(video(title: 'Faith #Shorts').isShortClip, isTrue);
  });

  test('unknown or zero length alone does not mark a Short', () {
    expect(video().isShortClip, isFalse);
    expect(video(duration: Duration.zero).isShortClip, isFalse);
  });

  test('audio-only messages are never Shorts', () {
    expect(
      video(duration: const Duration(seconds: 30), videoId: null).isShortClip,
      isFalse,
    );
  });
}
