import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KharisApp()));
    await tester.pump(const Duration(seconds: 1));
    // Splash screen should show KHARIS text
    expect(find.text('KHARIS'), findsOneWidget);

    // Wait for the splash screen timer (2500ms) to complete
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(); // Allow navigation to process
  });
}
