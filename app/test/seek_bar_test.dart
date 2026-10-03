import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';

const _width = 400.0;

Widget _host({
  required Duration position,
  required Duration duration,
  required ValueChanged<Duration> onSeek,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: _width,
          child: SeekBar(position: position, duration: duration, onSeek: onSeek),
        ),
      ),
    ),
  );
}

Finder get _track => find.descendant(
      of: find.byType(SeekBar),
      matching: find.byType(GestureDetector),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows elapsed on the left and time remaining on the right',
      (tester) async {
    await tester.pumpWidget(_host(
      position: const Duration(minutes: 4, seconds: 3),
      duration: const Duration(minutes: 9, seconds: 16),
      onSeek: (_) {},
    ));

    expect(find.text('4:03'), findsOneWidget);
    expect(find.text('-5:13'), findsOneWidget);
  });

  testWidgets('hour-long messages format with hours', (tester) async {
    await tester.pumpWidget(_host(
      position: const Duration(minutes: 5),
      duration: const Duration(hours: 1, minutes: 20),
      onSeek: (_) {},
    ));

    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('-1:15:00'), findsOneWidget);
  });

  testWidgets('unknown duration never shows a negative remainder',
      (tester) async {
    await tester.pumpWidget(_host(
      position: const Duration(seconds: 12),
      duration: Duration.zero,
      onSeek: (_) {},
    ));

    expect(find.text('0:12'), findsOneWidget);
    expect(find.text('-0:00'), findsOneWidget);
  });

  testWidgets('tapping the track seeks to that point', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_host(
      position: Duration.zero,
      duration: const Duration(minutes: 10),
      onSeek: seeks.add,
    ));

    final rect = tester.getRect(_track);
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));

    expect(seeks, [const Duration(minutes: 2, seconds: 30)]);
  });

  testWidgets('dragging previews the time and seeks once on release',
      (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_host(
      position: Duration.zero,
      duration: const Duration(minutes: 10),
      onSeek: seeks.add,
    ));

    final rect = tester.getRect(_track);
    final gesture =
        await tester.startGesture(Offset(rect.left + 20, rect.center.dy));
    await gesture.moveTo(Offset(rect.left + rect.width / 2, rect.center.dy));
    await tester.pump();

    // Labels follow the thumb, playback is not touched mid-drag.
    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('-5:00'), findsOneWidget);
    expect(seeks, isEmpty);

    await gesture.up();
    await tester.pump();

    expect(seeks, [const Duration(minutes: 5)]);
    // Drag preview cleared: labels return to the live position.
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('-10:00'), findsOneWidget);
  });

  testWidgets('dragging past either end clamps to the bounds', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_host(
      position: const Duration(minutes: 5),
      duration: const Duration(minutes: 10),
      onSeek: seeks.add,
    ));

    final rect = tester.getRect(_track);
    final gesture =
        await tester.startGesture(Offset(rect.center.dx, rect.center.dy));
    await gesture.moveTo(Offset(rect.right + 200, rect.center.dy));
    await gesture.up();
    await tester.pump();

    expect(seeks, [const Duration(minutes: 10)]);
  });
}
