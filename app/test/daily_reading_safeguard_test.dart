import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';

/// Records topic changes instead of touching FCM.
class _RecordingTopics extends NotificationService {
  final calls = <String>[];

  @override
  Future<bool> subscribeToTopic(String topic) async {
    calls.add('+$topic');
    return true;
  }

  @override
  Future<bool> unsubscribeFromTopic(String topic) async {
    calls.add('-$topic');
    return true;
  }
}

void main() {
  final index = BibleIndex.bundled();

  group('reading references only name real books and chapters', () {
    test('a chapter past the end of its book is rejected', () {
      expect(
        parseBibleReference('2 Corinthians 40', index),
        isA<ReferenceError>(),
      );
      expect(parseReadingReferences('2 Corinthians 40', index), isEmpty);
      expect(isValidReading('2 Corinthians 40', index), isFalse);
    });

    test("a book's last chapter is accepted", () {
      expect(parseReadingReferences('2 Corinthians 13', index), [
        const BibleLocation('2CO', 13),
      ]);
      expect(isValidReading('2 Corinthians 13', index), isTrue);
    });

    test('a book that is not in the Bible is rejected', () {
      expect(parseBibleReference('Hezekiah 3', index), isA<ReferenceError>());
      expect(parseReadingReferences('Hezekiah 3', index), isEmpty);
      expect(isValidReading('Hezekiah 3', index), isFalse);
    });

    test('Psalm 151 is rejected: the canon has 150 psalms', () {
      expect(parseBibleReference('Psalm 151', index), isA<ReferenceError>());
      expect(isValidReading('Psalm 151', index), isFalse);
    });

    test('a reading of two real passages is two passages', () {
      expect(parseReadingReferences('Romans 8:1-11; Psalm 23', index), [
        const BibleLocation('ROM', 8, verseStart: 1, verseEnd: 11),
        const BibleLocation('PSA', 23),
      ]);
      expect(isValidReading('Romans 8:1-11; Psalm 23', index), isTrue);
    });

    test('one invented passage makes the whole reading invalid', () {
      expect(isValidReading('Romans 8; 2 Corinthians 40', index), isFalse);
      expect(isValidReading('', index), isFalse);
    });
  });

  group('foreground pushes', () {
    test('a daily reading naming an invented chapter is not shown', () {
      expect(
        isShowableForegroundPush({
          'type': 'reading',
          'reference': '2 Corinthians 40',
        }, '2 Corinthians 40'),
        isFalse,
      );
      expect(
        isShowableForegroundPush({'type': 'reading'}, 'Hezekiah 3'),
        isFalse,
        reason: 'without data.reference the body is checked',
      );
    });

    test('a daily reading naming real passages is shown', () {
      expect(
        isShowableForegroundPush({
          'type': 'reading',
          'reference': 'Romans 8:1-11; Psalm 23',
        }, 'Romans 8:1-11; Psalm 23'),
        isTrue,
      );
      expect(
        isShowableForegroundPush({'type': 'reading'}, '2 Corinthians 13'),
        isTrue,
      );
    });

    test('other pushes are shown as before', () {
      expect(
        isShowableForegroundPush({'type': 'announcement'}, 'Hezekiah 3'),
        isTrue,
      );
    });
  });

  group('daily reading topic', () {
    test('the legacy topic is left first, whatever the preferences', () async {
      final topics = _RecordingTopics();
      await topics.applyPreferences({'dailyReading': true});
      expect(topics.calls, ['-daily_reading', '+daily_reading_v2']);

      topics.calls.clear();
      await topics.applyPreferences({'dailyReading': false});
      expect(topics.calls, ['-daily_reading', '-daily_reading_v2']);

      topics.calls.clear();
      await topics.applyPreferences({});
      expect(topics.calls, ['-daily_reading']);
    });

    test('a daily reading push opens the reader', () {
      expect(
        notificationTargetFor({'type': 'reading'}),
        const NotificationTarget('/reading', overlay: true),
      );
    });
  });
}
