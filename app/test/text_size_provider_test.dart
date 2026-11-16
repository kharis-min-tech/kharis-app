import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/text_size_provider.dart';

Future<(ProviderContainer, SharedPreferences)> _container([
  Map<String, Object> stored = const {},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

void main() {
  test('is Medium, at the system size, until the member chooses', () async {
    final (container, _) = await _container();

    expect(container.read(textSizeProvider), TextSizeChoice.medium);
    expect(container.read(textSizeFactorProvider), 1.0);
  });

  test('each choice has its label and factor', () {
    expect(
      [for (final c in TextSizeChoice.values) (c.label, c.factor)],
      [('Small', 0.9), ('Medium', 1.0), ('Large', 1.15)],
    );
  });

  test('a choice changes the factor and is stored', () async {
    final (container, prefs) = await _container();

    await container.read(textSizeProvider.notifier).set(TextSizeChoice.large);

    expect(container.read(textSizeProvider), TextSizeChoice.large);
    expect(container.read(textSizeFactorProvider), 1.15);
    expect(prefs.getString('settings_text_size'), 'large');
  });

  test('the stored choice is read back on the next launch', () async {
    final (container, _) = await _container({'settings_text_size': 'small'});

    expect(container.read(textSizeProvider), TextSizeChoice.small);
    expect(container.read(textSizeFactorProvider), 0.9);
  });

  test('a value it does not know reads as Medium', () async {
    final (container, _) = await _container({'settings_text_size': 'huge'});

    expect(container.read(textSizeProvider), TextSizeChoice.medium);
  });
}
