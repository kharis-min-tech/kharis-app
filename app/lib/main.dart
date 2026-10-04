import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:kharis_app/core/configs/app_startup.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/services/app_router.dart';
import 'features/shared_links/presentation/open_in_app_banner.dart';
import 'core/constants/api_config.dart';
import 'core/services/cache_service.dart';
import 'core/services/notification_service.dart';
import 'shared/providers/theme_provider.dart';
import 'core/theme/theme.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/providers/cache_provider.dart';
import 'shared/providers/sermon_provider.dart';
import 'shared/providers/notification_provider.dart';
import 'shared/providers/onboarding_provider.dart';

Future<void> main() async {
  // Catch all errors in release mode
  runZonedGuarded(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: binding);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      // Real paths on web (no `#/`), so a shared link such as
      // https://<AppLinks.host>/m/<id> routes in the web app exactly as it
      // does in the native apps. No-op off the web.
      usePathUrlStrategy();
      // Fonts ship in assets/google_fonts (google_fonts prefers bundled files
      // over fetching), so first launch renders the same offline as online.
      // Their SIL Open Font Licenses appear in the licences page.
      LicenseRegistry.addLicense(() async* {
        for (final family in const [
          'bricolagegrotesque',
          'hankengrotesk',
          'newsreader',
        ]) {
          yield LicenseEntryWithLineBreaks(
            ['google_fonts'],
            await rootBundle.loadString('assets/google_fonts/OFL-$family.txt'),
          );
        }
      });

      // Lock-screen / notification / CarPlay media controls (Now Playing).
      // Must run before any AudioPlayer is created. The transport is
      // Previous / Next message, driven by the queue window the audio
      // service loads (see AudioPlayerService), so the OS shows the same
      // controls as the in-app player and no ±seconds skip buttons.
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.kharis.church.channel.audio',
        androidNotificationChannelName: 'Kharis audio playback',
        androidNotificationOngoing: true,
      );
      FlutterError.onError = (details) {
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      // Loudly surface a Firebase SDK vs Cloud Functions project mismatch —
      // that silently splits Firestore/Auth/FCM away from the API's content.
      ApiConfig.warnIfProjectSplit();

      // Run independent startup work concurrently so first paint isn't blocked
      // by prefs + Hive + Firebase in series.
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        CacheService.init(),
        AppStartUp().setUp(),
      ]);
      final prefs = results[0] as SharedPreferences;
      final cacheService = results[1] as CacheService;
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cacheServiceProvider.overrideWithValue(cacheService),
            sermonArchiveCacheProvider.overrideWithValue(cacheService),
          ],
          child: const KharisApp(),
        ),
      );
      // Keep the branded splash up until the first themed frame paints, so
      // there's no white gap between the native splash and the app content.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => FlutterNativeSplash.remove(),
      );
    },
    (error, stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Uncaught error: $error\n$stack');
      }
    },
  );
}

/// Bounds for the member's system text size. Beyond 1.3x the fixed-height
/// cards and the mini player clip; below 0.85x text is no longer legible.
const double kMinTextScale = 0.85;
const double kMaxTextScale = 1.3;

/// `MaterialApp.builder` that honours the system text size within
/// [kMinTextScale]..[kMaxTextScale] for every route, dialog and sheet.
Widget clampTextScaling(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
      minScaleFactor: kMinTextScale,
      maxScaleFactor: kMaxTextScale,
      child: child ?? const SizedBox.shrink(),
    );

class KharisApp extends ConsumerWidget {
  const KharisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FCM setup (permission prompt, token, handlers) runs off the first frame:
    // this only kicks off the future, the widget tree never awaits it.
    ref.watch(notificationInitProvider);
    // Keeps preference-gated topic subscriptions in step with saved prefs.
    ref.watch(notificationTopicSyncProvider);
    // Guarantees a Firebase uid for every session (anonymous when the member
    // never signs in) so per-user data — playlists, notes — has somewhere to
    // live even on the login-free onboarding path.
    ref.watch(anonymousSignInProvider);
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (BuildContext context, child) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Kharis Church',
        themeMode: ref.watch(themeModeProvider),
        theme: kharisTheme(brightness: Brightness.light),
        darkTheme: kharisTheme(brightness: Brightness.dark),
        scaffoldMessengerKey: kharisMessengerKey,
        routerConfig: ref.watch(appRouterProvider),
        // On web, a shared link opened in the browser gets the "Open in the
        // Kharis app" bar above every route.
        builder: (context, child) => clampTextScaling(
          context,
          OpenInAppBanner(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
