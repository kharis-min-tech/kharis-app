import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/presentation/screens/admin_sermons_screen.dart';
import 'package:kharis_app/features/admin/providers/content_config_providers.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

Future<FakeFirebaseFirestore> _pumpScreen(WidgetTester tester) async {
  final db = FakeFirebaseFirestore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentConfigRepositoryProvider.overrideWithValue(
          ContentConfigRepository(firestore: db),
        ),
        adminSermonsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: AdminSermonsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Featured mode switches between Auto and Pinned', (tester) async {
    final db = await _pumpScreen(tester);
    expect(find.text('Stars only apply in Pinned mode.'), findsOneWidget);

    await tester.tap(find.text('Pinned'));
    await tester.pumpAndSettle();

    final doc = (await db.collection('config').doc('featured').get()).data()!;
    expect(doc['mode'], 'pinned');
    expect(find.text('Stars only apply in Pinned mode.'), findsNothing);
  });

  testWidgets('Featured Off writes off and explains what Messages leads with', (
    tester,
  ) async {
    final db = await _pumpScreen(tester);

    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();

    final doc = (await db.collection('config').doc('featured').get()).data()!;
    expect(doc['mode'], 'off');
    expect(
      find.text(
        'No featured carousel: Messages leads with the latest messages.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Studio has no Message of the Day scheduling', (
    tester,
  ) async {
    await _pumpScreen(tester);
    expect(find.textContaining('Message of the Day'), findsNothing);
    expect(find.text('Choose message'), findsNothing);
  });
}
