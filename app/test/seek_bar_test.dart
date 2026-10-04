import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';

const _width = 400.0;

Widget _host({
  required Duration position,
  required Duration duration,
  required ValueChanged<Duration> onSeek,
  List<Duration> pins = const [],
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: _width,
          child: SeekBar(
            position: position,
            duration: duration,
            onSeek: onSeek,
            pins: pins,
          ),
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

  testWidgets('shows elapsed on the left and time remaining on the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        position: const Duration(minutes: 4, seconds: 3),
        duration: const Duration(minutes: 9, seconds: 16),
        onSeek: (_) {},
      ),
    );

    expect(find.text('4:03'), findsOneWidget);
    expect(find.text('-5:13'), findsOneWidget);
  });

  testWidgets('hour-long messages format with hours', (tester) async {
    await tester.pumpWidget(
      _host(
        position: const Duration(minutes: 5),
        duration: const Duration(hours: 1, minutes: 20),
        onSeek: (_) {},
      ),
    );

    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('-1:15:00'), findsOneWidget);
  });

  testWidgets(
    'unknown duration shows placeholders, never a negative remainder',
    (tester) async {
      await tester.pumpWidget(
        _host(position: Duration.zero, duration: Duration.zero, onSeek: (_) {}),
      );

      expect(find.text('--:--'), findsNWidgets(2));
      expect(find.text('-0:00'), findsNothing);
    },
  );

  testWidgets('unknown duration keeps a live elapsed time readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        position: const Duration(seconds: 12),
        duration: Duration.zero,
        onSeek: (_) {},
      ),
    );

    expect(find.text('0:12'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
  });

  testWidgets('taps and drags are ignored until the duration is known', (
    tester,
  ) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      _host(
        position: const Duration(minutes: 3),
        duration: Duration.zero,
        onSeek: seeks.add,
      ),
    );

    final rect = tester.getRect(find.byType(SeekBar));
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.top + 14));
    await tester.dragFrom(
      Offset(rect.left + 10, rect.top + 14),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();

    expect(seeks, isEmpty, reason: 'seeking to 0:00 would lose the place');
  });

  testWidgets('tapping the track seeks to that point', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      _host(
        position: Duration.zero,
        duration: const Duration(minutes: 10),
        onSeek: seeks.add,
      ),
    );

    final rect = tester.getRect(_track);
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));

    expect(seeks, [const Duration(minutes: 2, seconds: 30)]);
  });

  testWidgets('dragging previews the time and seeks once on release', (
    tester,
  ) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      _host(
        position: Duration.zero,
        duration: const Duration(minutes: 10),
        onSeek: seeks.add,
      ),
    );

    final rect = tester.getRect(_track);
    final gesture = await tester.startGesture(
      Offset(rect.left + 20, rect.center.dy),
    );
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
    await tester.pumpWidget(
      _host(
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 10),
        onSeek: seeks.add,
      ),
    );

    final rect = tester.getRect(_track);
    final gesture = await tester.startGesture(
      Offset(rect.center.dx, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.right + 200, rect.center.dy));
    await gesture.up();
    await tester.pump();

    expect(seeks, [const Duration(minutes: 10)]);
  });

  group('note pins', () {
    const tenMinutes = Duration(minutes: 10);
    // The test host has no theme extension, so the bar paints the light
    // palette.
    final accent = KharisColors.light.accentInk;
    final halo = KharisColors.light.bg;
    const outer = SeekBar.pinRadius + SeekBar.pinHalo;
    // The track is 28 px tall; the rail runs through its middle.
    const cy = 14.0;

    RenderObject timeline(WidgetTester tester) => tester.renderObject(
      find.descendant(
        of: find.byType(SeekBar),
        matching: find.byType(CustomPaint),
      ),
    );

    /// Each pin is a halo ring then a gold core, in timeline order; the
    /// thumb is painted last, over them.
    PaintPattern pinsThenThumb(List<double> xs, {required double thumbX}) {
      final pattern = paints;
      for (final x in xs) {
        pattern
          ..circle(x: x, y: cy, radius: outer, color: halo)
          ..circle(x: x, y: cy, radius: SeekBar.pinRadius, color: accent);
      }
      return pattern..circle(x: thumbX, y: cy, radius: 6);
    }

    test('pins sit at their fraction of the track', () {
      expect(
        SeekBar.pinCentres(
          const [
            Duration(minutes: 2, seconds: 30),
            Duration(minutes: 5),
            Duration(minutes: 7, seconds: 30),
          ],
          duration: tenMinutes,
          width: _width,
        ),
        [100.0, 200.0, 300.0],
      );
    });

    test('unsorted pins are placed in timeline order', () {
      expect(
        SeekBar.pinCentres(
          const [Duration(minutes: 5), Duration(minutes: 2, seconds: 30)],
          duration: tenMinutes,
          width: _width,
        ),
        [100.0, 200.0],
      );
    });

    test('pins at either end stay whole inside the track', () {
      expect(
        SeekBar.pinCentres(
          const [Duration.zero, tenMinutes],
          duration: tenMinutes,
          width: _width,
        ),
        [outer, _width - outer],
      );
    });

    test('pins closer than a marker merge into the earliest one', () {
      // 600 px over 600 s: one pixel per second, so seconds read as pixels.
      const width = 600.0;
      const duration = Duration(seconds: 600);
      List<double> at(List<int> seconds) => SeekBar.pinCentres(
        [for (final s in seconds) Duration(seconds: s)],
        duration: duration,
        width: width,
      );

      expect(SeekBar.pinWidth, 9.0);
      expect(at([100, 108]), [100.0], reason: '8 px apart: they would overlap');
      expect(at([100, 109]), [100.0, 109.0], reason: 'a full marker apart');
      // A chain merges against the last marker DRAWN, so no two drawn
      // markers ever overlap, yet a long run is not swallowed whole.
      expect(at([100, 105, 110, 115]), [100.0, 110.0]);
      // Clamping can push edge pins together; they merge too.
      expect(at([0, 2]), [outer]);
    });

    test('pins outside the timeline are ignored', () {
      expect(
        SeekBar.pinCentres(
          const [
            Duration(seconds: -1),
            Duration(minutes: 5),
            Duration(minutes: 10, milliseconds: 1),
          ],
          duration: tenMinutes,
          width: _width,
        ),
        [200.0],
      );
    });

    test('nothing is placed while the duration is unknown', () {
      expect(
        SeekBar.pinCentres(
          const [Duration(minutes: 1)],
          duration: Duration.zero,
          width: _width,
        ),
        isEmpty,
      );
    });

    testWidgets('the bar paints a gold bead at each pin, under the thumb', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          position: const Duration(minutes: 5),
          duration: tenMinutes,
          onSeek: (_) {},
          pins: const [
            Duration(minutes: 2, seconds: 30),
            Duration(minutes: 7, seconds: 30),
          ],
        ),
      );

      final painted = timeline(tester);
      // One bead on the played portion, one on the rail, then the thumb.
      expect(painted, pinsThenThumb([100, 300], thumbX: 200));
      expect(painted, paintsExactlyCountTimes(#drawCircle, 5));
    });

    testWidgets('close pins paint as one bead', (tester) async {
      await tester.pumpWidget(
        _host(
          position: Duration.zero,
          duration: tenMinutes,
          onSeek: (_) {},
          // 5 s apart on a 10 min / 400 px bar: about 3 px.
          pins: const [Duration(minutes: 5), Duration(minutes: 5, seconds: 5)],
        ),
      );

      final painted = timeline(tester);
      expect(painted, pinsThenThumb([200], thumbX: 0));
      expect(painted, paintsExactlyCountTimes(#drawCircle, 3));
    });

    testWidgets('out-of-range pins and an unknown duration paint nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          position: Duration.zero,
          duration: tenMinutes,
          onSeek: (_) {},
          pins: const [Duration(minutes: 11), Duration(seconds: -5)],
        ),
      );
      expect(
        timeline(tester),
        paintsExactlyCountTimes(#drawCircle, 1),
        reason: 'the thumb only',
      );

      await tester.pumpWidget(
        _host(
          position: Duration.zero,
          duration: Duration.zero,
          onSeek: (_) {},
          pins: const [Duration(minutes: 1)],
        ),
      );
      expect(
        timeline(tester),
        paintsExactlyCountTimes(#drawCircle, 0),
        reason: 'no thumb and no pins until the duration is known',
      );
    });

    testWidgets('the slider label counts the notes on the timeline', (
      tester,
    ) async {
      Future<void> pump(List<Duration> pins, {Duration? duration}) =>
          tester.pumpWidget(
            _host(
              position: Duration.zero,
              duration: duration ?? tenMinutes,
              onSeek: (_) {},
              pins: pins,
            ),
          );
      // The slider node also folds in the time readouts below the bar, one
      // per line; the label proper is the first line.
      String label() =>
          tester.getSemantics(find.byType(SeekBar)).label.split('\n').first;

      await pump(const [
        Duration(minutes: 1),
        Duration(minutes: 5),
        // Merged with the 5:00 bead, but still its own note.
        Duration(minutes: 5, seconds: 1),
      ]);
      expect(label(), 'Playback position, 3 notes on this message');

      await pump(const [Duration(minutes: 1), Duration(minutes: 12)]);
      expect(label(), 'Playback position, 1 note on this message');

      await pump(const []);
      expect(label(), 'Playback position');

      await pump(const [Duration(minutes: 1)], duration: Duration.zero);
      expect(label(), 'Playback position', reason: 'no pins drawn yet');
    });
  });
}
