import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/app_typography.dart';

/// The app must render identically offline: every font weight and style
/// AppTypography uses is bundled in assets/google_fonts, so nothing is ever
/// fetched from fonts.gstatic.com at runtime (first launch on a poor
/// connection used to fall back to system fonts).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final weights = {
    FontWeight.w400: 'Regular',
    FontWeight.w500: 'Medium',
    FontWeight.w600: 'SemiBold',
    FontWeight.w700: 'Bold',
    FontWeight.w800: 'ExtraBold',
  };

  test('every weight and style the app uses is in the asset bundle', () async {
    final expected = [
      for (final name in weights.values) ...[
        'BricolageGrotesque-$name.ttf',
        'HankenGrotesk-$name.ttf',
        'Newsreader-$name.ttf',
        'Newsreader-${name == 'Regular' ? '' : name}Italic.ttf',
      ],
    ];
    for (final file in expected) {
      await expectLater(
        rootBundle.load('assets/google_fonts/$file'),
        completes,
        reason: '$file must be bundled',
      );
    }
  });

  test(
    'AppTypography loads every variant without touching the network',
    () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await GoogleFonts.pendingFonts([
        for (final w in weights.keys) ...[
          AppTypography.display(weight: w),
          AppTypography.ui(weight: w),
          AppTypography.serif(weight: w),
          AppTypography.serif(weight: w, italic: true),
        ],
      ]);

      // google_fonts reports a missing asset through FlutterError (fetching is
      // off), not through the returned future.
      expect(reported.map((e) => e.exceptionAsString()), isEmpty);
    },
  );
}
