import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/role_card.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

void main() {
  setUpAll(loadDesignAssets);

  testWidgets('RoleCard renders its title + description and fires onTap', (
    tester,
  ) async {
    var tapped = false;
    await pumpDesign(
      tester,
      RoleCard(
        icon: KIcons.home,
        title: 'Member',
        description: 'I call Kharis my church home',
        onTap: () => tapped = true,
      ),
      dark: false,
    );

    expect(find.text('Member'), findsOneWidget);
    expect(find.text('I call Kharis my church home'), findsOneWidget);

    await tester.tap(find.byType(RoleCard));
    expect(tapped, isTrue);
  });
}
