import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/shared_links/presentation/open_in_app_banner.dart';
import 'package:kharis_app/features/shared_links/presentation/shared_link_screens.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

/// A phone at the design width.
const Size _phone = Size(KSize.designWidth, 844);

/// Pumps [child] as the whole screen at 390 wide in the new theme.
Future<void> _pumpScreen(
  WidgetTester tester,
  Widget child, {
  required bool dark,
  required double textScale,
  List<Override> overrides = const [],
  TransitionBuilder? above,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: KharisTheme.light(),
        darkTheme: KharisTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: above == null ? app! : above(context, app),
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Unmounts the screen so its lookup timers are cancelled.
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

/// Runs [body] in light and dark at 100% and 130% text.
void _everyMode(
  String description,
  Future<void> Function(WidgetTester tester, bool dark, double textScale) body,
) {
  for (final dark in [false, true]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets('$description (${dark ? 'dark' : 'light'}, '
          '${(textScale * 100).round()}%)', (tester) async {
        await body(tester, dark, textScale);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void main() {
  setUpAll(loadDesignAssets);

  group('shared message link', () {
    _everyMode('looking the message up', (tester, dark, textScale) async {
      await _pumpScreen(
        tester,
        const SharedMessageScreen(id: 'slow'),
        dark: dark,
        textScale: textScale,
        overrides: [
          sermonByIdProvider.overrideWith(
            (ref, id) => const AsyncLoading<Sermon?>(),
          ),
        ],
      );
      expect(find.text('Opening message'), findsOneWidget);
      expect(find.byType(KSkeleton), findsWidgets);
    });

    _everyMode('message not found', (tester, dark, textScale) async {
      await _pumpScreen(
        tester,
        const SharedMessageScreen(id: 'gone'),
        dark: dark,
        textScale: textScale,
        overrides: [
          sermonByIdProvider.overrideWith(
            (ref, id) => const AsyncData<Sermon?>(null),
          ),
        ],
      );
      expect(find.text('We couldn\u2019t find that message'), findsOneWidget);
      expect(find.byKey(const Key('shared-link-home')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('shared event link', () {
    _everyMode('event not found', (tester, dark, textScale) async {
      await _pumpScreen(
        tester,
        const SharedEventScreen(id: 'gone'),
        dark: dark,
        textScale: textScale,
        overrides: [
          eventByIdProvider.overrideWith((ref, id) async => null as Event?),
        ],
      );
      expect(find.text('We couldn\u2019t find that event'), findsOneWidget);
      expect(find.byKey(const Key('shared-link-home')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('shared announcement link', () {
    _everyMode('looking the announcement up', (tester, dark, textScale) async {
      await _pumpScreen(
        tester,
        const SharedAnnouncementScreen(id: 'slow'),
        dark: dark,
        textScale: textScale,
        overrides: [
          sharedAnnouncementProvider.overrideWith(
            (ref, id) => const AsyncLoading<NewsItem?>(),
          ),
        ],
      );
      expect(find.text('Opening announcement'), findsOneWidget);
      expect(find.byType(KSkeleton), findsWidgets);
    });

    _everyMode('announcement not found', (tester, dark, textScale) async {
      await _pumpScreen(
        tester,
        const SharedAnnouncementScreen(id: 'gone'),
        dark: dark,
        textScale: textScale,
        overrides: [
          sharedAnnouncementProvider.overrideWith(
            (ref, id) => const AsyncData<NewsItem?>(null),
          ),
        ],
      );
      expect(
        find.text('We couldn\u2019t find that announcement'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shared-link-home')), findsOneWidget);
    });
  });

  group('not-found screen', () {
    _everyMode('without a retry', (tester, dark, textScale) async {
      await _pumpScreen(
        tester,
        const SharedLinkNotFoundScreen(title: 'We couldn\u2019t find that'),
        dark: dark,
        textScale: textScale,
      );
      expect(find.byKey(const Key('shared-link-home')), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('open-in-app banner', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      _everyMode('over the web app on ${platform.name}', (
        tester,
        dark,
        textScale,
      ) async {
        await _pumpScreen(
          tester,
          const Scaffold(body: Text('web app')),
          dark: dark,
          textScale: textScale,
          above: (context, app) => OpenInAppBanner(
            landed: Uri.parse('https://kharis-app-47c49.web.app/m/yt_abc?t=95'),
            isWeb: true,
            platform: platform,
            child: app!,
          ),
        );
        expect(find.byKey(const Key('open-in-app-banner')), findsOneWidget);
        expect(find.text('Open in the Kharis app'), findsOneWidget);
        expect(
          find.text('Get the app'),
          platform == TargetPlatform.iOS ? findsNothing : findsOneWidget,
        );
        // The dismiss button is labelled and at least 44 pt each way.
        final dismiss = find.byKey(const Key('open-in-app-dismiss'));
        expect(tester.widget<KIconButton>(dismiss).label, 'Dismiss');
        final size = tester.getSize(dismiss);
        expect(size.width, greaterThanOrEqualTo(KSize.touchMin));
        expect(size.height, greaterThanOrEqualTo(KSize.touchMin));

        await tester.tap(dismiss);
        await tester.pump();
        expect(find.byKey(const Key('open-in-app-banner')), findsNothing);
        expect(find.text('web app'), findsOneWidget);
      });
    }
  });
}
