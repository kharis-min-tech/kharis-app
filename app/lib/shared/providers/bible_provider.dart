import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/data/bible_repository.dart';
import 'onboarding_provider.dart';

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => BibleRepository(),
);

/// NIV 2011, the translation members start on.
const kDefaultBibleVersion = BibleVersion(
  id: BibleRepository.defaultBibleId,
  abbreviation: BibleRepository.defaultBibleAbbreviation,
  title: 'New International Version 2011',
);

/// The member's reading translation, remembered on this device.
class SelectedBibleController extends StateNotifier<BibleVersion> {
  SelectedBibleController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static const idKey = 'bible_version_id';
  static const abbreviationKey = 'bible_version_abbreviation';
  static const titleKey = 'bible_version_title';

  static BibleVersion _load(SharedPreferences prefs) {
    final id = prefs.getInt(idKey);
    final abbreviation = prefs.getString(abbreviationKey);
    if (id == null || abbreviation == null) return kDefaultBibleVersion;
    // A version the church no longer approves is never reopened.
    if (!BibleRepository.approvedBibleIds.contains(id)) {
      return kDefaultBibleVersion;
    }
    return BibleVersion(
      id: id,
      abbreviation: abbreviation,
      title: prefs.getString(titleKey) ?? '',
    );
  }

  Future<void> select(BibleVersion version) async {
    state = version;
    await _prefs.setInt(idKey, version.id);
    await _prefs.setString(abbreviationKey, version.abbreviation);
    await _prefs.setString(titleKey, version.title);
  }
}

final selectedBibleProvider =
    StateNotifierProvider<SelectedBibleController, BibleVersion>(
      (ref) => SelectedBibleController(ref.watch(sharedPreferencesProvider)),
    );

/// Versions licensed for the app key.
final biblesProvider = FutureProvider<List<BibleVersion>>(
  (ref) => ref.watch(bibleRepositoryProvider).getBibles(),
);

/// Books and chapters of a version. Falls back to the bundled 66-book table
/// when the list cannot be fetched (offline), so browsing still works and
/// only the chapter text shows an error with Retry.
final bibleIndexProvider = FutureProvider.family<BibleIndex, int>((
  ref,
  bibleId,
) async {
  try {
    return BibleIndex(
      await ref.watch(bibleRepositoryProvider).getBooks(bibleId),
    );
  } on Object {
    return BibleIndex.bundled();
  }
});

/// Passage for (usfm, version), cached per pair by the repository.
final passageProvider =
    FutureProvider.family<
      BiblePassage,
      ({String usfm, int bibleId, String abbrev})
    >(
      (ref, key) => ref
          .watch(bibleRepositoryProvider)
          .getPassage(key.usfm, bibleId: key.bibleId, abbreviation: key.abbrev),
    );
