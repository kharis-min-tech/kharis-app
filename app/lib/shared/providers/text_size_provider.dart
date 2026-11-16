import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_provider.dart';

const _kTextSizeKey = 'settings_text_size';

/// The member's text size choice in More. Each multiplies the phone's own
/// text size, so the system setting still applies.
enum TextSizeChoice {
  small('Small', 0.9),
  medium('Medium', 1.0),
  large('Large', 1.15);

  const TextSizeChoice(this.label, this.factor);

  /// What the member reads in More.
  final String label;

  /// What the system text scale is multiplied by.
  final double factor;
}

/// The member's text size, persisted across launches. Medium until they
/// pick another.
class TextSizeController extends StateNotifier<TextSizeChoice> {
  TextSizeController(this._ref) : super(_read(_ref));

  final Ref _ref;

  static TextSizeChoice _read(Ref ref) {
    final raw = ref.read(sharedPreferencesProvider).getString(_kTextSizeKey);
    return TextSizeChoice.values.asNameMap()[raw] ?? TextSizeChoice.medium;
  }

  Future<void> set(TextSizeChoice choice) async {
    if (choice == state) return;
    state = choice;
    await _ref
        .read(sharedPreferencesProvider)
        .setString(_kTextSizeKey, choice.name);
  }
}

final textSizeProvider =
    StateNotifierProvider<TextSizeController, TextSizeChoice>(
      TextSizeController.new,
    );

/// What the system text scale is multiplied by for the member's choice.
final textSizeFactorProvider = Provider<double>(
  (ref) => ref.watch(textSizeProvider).factor,
);
