import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/theme.dart';
import 'core/services/app_router.dart';
import 'shared/providers/onboarding_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KharisApp(),
    ),
  );
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
