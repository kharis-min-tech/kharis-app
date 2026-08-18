import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/player/presentation/media_mode.dart';
import 'package:kharis_app/shared/models/sermon.dart';

Sermon _sermon({String audioUrl = '', String? videoId}) => Sermon(
      id: 's1',
      title: 'Walking in Faith',
      speaker: 'Pastor A',
      audioUrl: audioUrl,
      videoId: videoId,
    );

void main() {
  group('resolveInitialMode', () {
    test('audio wins when the sermon carries both media and nothing is asked',
        () {
      final sermon = _sermon(audioUrl: 'https://a/x.mp3', videoId: 'abc123');
      expect(resolveInitialMode(sermon, null), MediaMode.audio);
    });

    test('honours an explicit video request when a video exists', () {
      final sermon = _sermon(audioUrl: 'https://a/x.mp3', videoId: 'abc123');
      expect(resolveInitialMode(sermon, MediaMode.video), MediaMode.video);
    });

    test('honours an explicit audio request when audio exists', () {
      final sermon = _sermon(audioUrl: 'https://a/x.mp3', videoId: 'abc123');
      expect(resolveInitialMode(sermon, MediaMode.audio), MediaMode.audio);
    });

    test('audio-only sermon opens in audio even when video is requested', () {
      final sermon = _sermon(audioUrl: 'https://a/x.mp3');
      expect(resolveInitialMode(sermon, MediaMode.video), MediaMode.audio);
    });

    test('video-only sermon opens in video, whatever was requested', () {
      final sermon = _sermon(videoId: 'abc123');
      expect(resolveInitialMode(sermon, null), MediaMode.video);
      expect(resolveInitialMode(sermon, MediaMode.audio), MediaMode.video);
      expect(resolveInitialMode(sermon, MediaMode.video), MediaMode.video);
    });

    test('sermon with no media falls back to audio, whose layout carries '
        'the failure banner', () {
      final sermon = _sermon();
      expect(resolveInitialMode(sermon, null), MediaMode.audio);
      expect(resolveInitialMode(sermon, MediaMode.video), MediaMode.audio);
    });

    test('whitespace-only urls count as missing media', () {
      final sermon = _sermon(audioUrl: '   ', videoId: '  ');
      expect(sermon.hasAudio, isFalse);
      expect(sermon.hasVideo, isFalse);
      expect(resolveInitialMode(sermon, null), MediaMode.audio);
    });
  });
}
