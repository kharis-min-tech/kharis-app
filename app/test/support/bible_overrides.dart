import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

/// What Home's Bible row reads to name today's chapters: the member's
/// translation (default, from empty preferences) and the bundled book list,
/// so no test reaches the Bible API.
Future<List<Override>> bibleRowOverrides() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    bibleIndexProvider.overrideWith((ref, id) async => BibleIndex.bundled()),
  ];
}
