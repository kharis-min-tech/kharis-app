import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/role_card.dart';

void main() {
  // Fonts are fetched from the network at runtime; disable that in tests so the
  // widget tree builds with a fallback font instead of failing.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('RoleCard renders its title + description and fires onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoleCard(
            icon: Icons.home_outlined,
            title: 'Member',
            description: 'I call Kharis my church home',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Member'), findsOneWidget);
    expect(find.text('I call Kharis my church home'), findsOneWidget);

    await tester.tap(find.byType(RoleCard));
    expect(tapped, isTrue);
  });
}
