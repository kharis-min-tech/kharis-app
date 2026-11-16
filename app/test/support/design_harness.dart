import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:kharis_app/ui/gallery/component_gallery_screen.dart';

/// The design width every mock-up is drawn at.
const Size designSurface = Size(KSize.designWidth, 4000);

/// Loads the bundled Plus Jakarta Sans files so text renders as real glyphs
/// in tests, and warms the icon cache so icons are there on the first frame.
/// Call from `setUpAll`.
Future<void> loadDesignAssets() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader(KType.fontFamily);
  for (final weight in const ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File(
      'assets/fonts/PlusJakartaSans-$weight.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  for (final icon in galleryIcons.values) {
    await SvgAssetLoader(icon).loadBytes(null);
  }
}

/// Wraps [child] in the new theme at the given mode and text size.
Widget designHarness({
  required Widget child,
  required bool dark,
  double textScale = 1,
  bool reduceMotion = true,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: KharisTheme.light(),
    darkTheme: KharisTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: app!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Pumps [child] in [designHarness] on a phone-width surface and waits for
/// its images and icons.
Future<void> pumpDesign(
  WidgetTester tester,
  Widget child, {
  required bool dark,
  double textScale = 1,
  bool reduceMotion = true,
}) async {
  tester.view.physicalSize = designSurface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    designHarness(
      dark: dark,
      textScale: textScale,
      reduceMotion: reduceMotion,
      child: child,
    ),
  );
  // Images decode on real time, not the test clock.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
