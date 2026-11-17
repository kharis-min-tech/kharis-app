// The parse cache behind the reader's "preached from" markers: one parse per
// passage string, emptied on demand for tests, and bounded.
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/related_messages_provider.dart';

void main() {
  final canon = BibleIndex.bundled();
  setUp(clearParsedPassagesCache);

  test('parses a passage once, then answers from the cache', () {
    final first = parsePassageCached('John 3:16', canon);
    expect(first, isNotEmpty);
    expect(parsedPassagesCacheSize, 1);
    expect(identical(parsePassageCached('John 3:16', canon), first), isTrue);
    expect(parsedPassagesCacheSize, 1);
  });

  test('clear starts cold', () {
    parsePassageCached('Romans 8:1', canon);
    clearParsedPassagesCache();
    expect(parsedPassagesCacheSize, 0);
  });

  test('never holds more than the cap', () {
    for (var i = 0; i <= kParsedPassagesCap; i++) {
      parsePassageCached('not a passage $i', canon);
    }
    expect(parsedPassagesCacheSize, lessThanOrEqualTo(kParsedPassagesCap));
  });
}
