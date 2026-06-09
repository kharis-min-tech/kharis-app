import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/app_router.dart';
import 'core/services/cache_service.dart';
import 'core/services/firebase_service.dart';
import 'core/theme/theme.dart';
import 'shared/providers/cache_provider.dart';
import 'shared/providers/onboarding_provider.dart';

Future<void> main() async {
  // Catch all errors in release mode
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    if (kUseFirebase) {
      await FirebaseService.init();
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheService = await CacheService.init();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cacheServiceProvider.overrideWithValue(cacheService),
        ],
        child: const KharisApp(),
      ),
    );
  }, (error, stack) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Uncaught error: $error\n$stack');
    }
  });
}

class KharisApp extends ConsumerWidget {
  const KharisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kharis Church',
      debugShowCheckedModeBanner: false,
      theme: kharisTheme(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
