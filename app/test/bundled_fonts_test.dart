import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app must render identically offline: every Plus Jakarta Sans weight
/// the theme uses is bundled, so nothing is ever fetched at runtime, and its
/// licence (shown on the licences page, registered in `main`) is bundled too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every weight the theme uses is in the asset bundle', () async {
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      final file = 'assets/fonts/PlusJakartaSans-$weight.ttf';
      await expectLater(
        rootBundle.load(file),
        completes,
        reason: '$file must be bundled',
      );
    }
  });

  test('the font licence is bundled for the licences page', () async {
    final licence = await rootBundle.loadString('assets/fonts/OFL.txt');
    expect(licence, contains('SIL Open Font License'));
  });
}
