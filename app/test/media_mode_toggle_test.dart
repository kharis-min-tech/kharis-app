import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/features/player/presentation/media_mode.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/shared/models/sermon.dart';

Sermon _sermon({String audioUrl = '', String? videoId}) => Sermon(
      id: 's1',
      title: 'Walking in Faith',
      speaker: 'Pastor A',
      audioUrl: audioUrl,
      videoId: videoId,
    );

Widget _host(Sermon sermon, MediaMode active, ValueChanged<MediaMode> onSelect) {
  return MaterialApp(
    home: Scaffold(
      body: MediaModeToggle(
        sermon: sermon,
        activeMode: active,
        onSelect: onSelect,
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('both media: both chips enabled, tapping the inactive one fires',
      (tester) async {
    final sermon = _sermon(audioUrl: 'https://a/x.mp3', videoId: 'abc123');
    MediaMode? selected;
    await tester.pumpWidget(_host(sermon, MediaMode.audio, (m) => selected = m));

    await tester.tap(find.text('Video'));
    expect(selected, MediaMode.video);

    // The active chip never re-fires.
    selected = null;
    await tester.tap(find.text('Audio'));
    expect(selected, isNull);

    // Neither chip carries a disabled tooltip.
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('audio-only: Video chip is disabled, non-interactive, labelled',
      (tester) async {
    final sermon = _sermon(audioUrl: 'https://a/x.mp3');
    MediaMode? selected;
    await tester.pumpWidget(_host(sermon, MediaMode.audio, (m) => selected = m));

    await tester.tap(find.text('Video'));
    expect(selected, isNull);

    expect(
      find.byTooltip('No video recording for this message'),
      findsOneWidget,
    );
    final semantics = tester.getSemantics(find.text('Video'));
    expect(semantics.label, contains('No video recording for this message'));
  });

  testWidgets('video-only: Audio chip is disabled, non-interactive, labelled',
      (tester) async {
    final sermon = _sermon(videoId: 'abc123');
    MediaMode? selected;
    await tester.pumpWidget(_host(sermon, MediaMode.video, (m) => selected = m));

    await tester.tap(find.text('Audio'));
    expect(selected, isNull);

    expect(
      find.byTooltip('No audio recording for this message'),
      findsOneWidget,
    );
    final semantics = tester.getSemantics(find.text('Audio'));
    expect(semantics.label, contains('No audio recording for this message'));
  });
}
