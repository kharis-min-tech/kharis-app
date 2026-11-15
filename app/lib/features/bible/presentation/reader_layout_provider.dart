import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// How the member likes a chapter laid out, remembered on this device: one
/// verse per line (the default) or the translation's paragraphs.
class ReaderLayoutController extends StateNotifier<KReaderLayout> {
  ReaderLayoutController(this._prefs)
    : super(
        KReaderLayout.values.asNameMap()[_prefs.getString(prefsKey)] ??
            KReaderLayout.verses,
      );

  final SharedPreferences _prefs;

  static const String prefsKey = 'bible_reader_layout';

  Future<void> select(KReaderLayout layout) async {
    state = layout;
    await _prefs.setString(prefsKey, layout.name);
  }
}

final readerLayoutProvider =
    StateNotifierProvider<ReaderLayoutController, KReaderLayout>(
      (ref) => ReaderLayoutController(ref.watch(sharedPreferencesProvider)),
    );
