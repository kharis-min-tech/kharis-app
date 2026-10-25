import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/time_skip.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('TimeSkip.target', () {
    const len = Duration(minutes: 50);

    test('moves by the offset inside the message', () {
      expect(
        TimeSkip.target(const Duration(minutes: 10), -TimeSkip.back, len),
        const Duration(minutes: 9, seconds: 45),
      );
      expect(
        TimeSkip.target(const Duration(minutes: 10), TimeSkip.forward, len),
        const Duration(minutes: 10, seconds: 30),
      );
    });

    test('stops at the start and at the end', () {
      expect(
        TimeSkip.target(const Duration(seconds: 5), -TimeSkip.back, len),
        Duration.zero,
      );
      expect(
        TimeSkip.target(
          const Duration(minutes: 49, seconds: 50),
          TimeSkip.forward,
          len,
        ),
        len,
      );
    });

    test('an unknown length only bounds the start', () {
      expect(
        TimeSkip.target(const Duration(minutes: 3), TimeSkip.forward, null),
        const Duration(minutes: 3, seconds: 30),
      );
    });
  });

  testWidgets('back 15 and forward 30 send signed offsets; '
      'without a seek they are disabled', (tester) async {
    final offsets = <Duration>[];
    Future<void> pump({required bool canSeek}) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(extensions: const [KharisColors.dark]),
          home: Scaffold(
            body: PlayerControls(
              transport: TransportBinding(
                isPlaying: true,
                isBuffering: false,
                speed: 1,
                repeatOn: false,
                onPlay: () {},
                onPause: () {},
                onSetSpeed: (_) {},
                onToggleRepeat: () {},
                onSeekBy: canSeek ? offsets.add : null,
              ),
            ),
          ),
        ),
      ),
    );

    await pump(canSeek: true);
    await tester.tap(find.byKey(const Key('skip-back')));
    await tester.tap(find.byKey(const Key('skip-forward')));
    expect(offsets, [
      const Duration(seconds: -15),
      const Duration(seconds: 30),
    ]);
    expect(find.bySemanticsLabel('Back 15 seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Forward 30 seconds'), findsOneWidget);

    await pump(canSeek: false);
    await tester.tap(find.byKey(const Key('skip-back')));
    expect(offsets, hasLength(2));
  });
}
