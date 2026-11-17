import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/core/utils/service_time.dart';

void main() {
  group('formatServiceTime', () {
    test('shows the 24-hour shape as HH:mm', () {
      expect(formatServiceTime('14:00'), '14:00');
      expect(formatServiceTime('14:00:00'), '14:00');
      expect(formatServiceTime('09:05'), '09:05');
      expect(formatServiceTime('9:05'), '09:05');
      expect(formatServiceTime('23:59'), '23:59');
    });

    test('midnight and noon stay on the 24-hour clock', () {
      expect(formatServiceTime('00:30'), '00:30');
      expect(formatServiceTime('12:00'), '12:00');
    });

    test('reads an older stored 12-hour time as 24-hour', () {
      expect(formatServiceTime('2:00 PM'), '14:00');
      expect(formatServiceTime('9:00 AM'), '09:00');
      expect(formatServiceTime('12:30 am'), '00:30');
      expect(formatServiceTime('12:00 PM'), '12:00');
      expect(formatServiceTime('7:30pm'), '19:30');
    });

    test('passes through free text an admin typed by hand', () {
      expect(formatServiceTime('Sundays 10am & 6pm'), 'Sundays 10am & 6pm');
    });

    test('passes through out-of-range clock values rather than wrapping', () {
      expect(formatServiceTime('25:00'), '25:00');
      expect(formatServiceTime('10:99'), '10:99');
      expect(formatServiceTime('13:00 PM'), '13:00 PM');
    });

    test('trims, and treats blank as unset', () {
      expect(formatServiceTime('  14:00  '), '14:00');
      expect(formatServiceTime(''), isNull);
      expect(formatServiceTime('   '), isNull);
      expect(formatServiceTime(null), isNull);
    });
  });

  group('startMinutes', () {
    test('reads the same shapes formatServiceTime does', () {
      expect(startMinutes('19:00'), 19 * 60);
      expect(startMinutes('19:30:00'), 19 * 60 + 30);
      expect(startMinutes(' 7:05 PM '), 19 * 60 + 5);
      expect(startMinutes('12:00 am'), 0);
      expect(startMinutes('12:00 PM'), 12 * 60);
    });

    test('is null for anything that is not a clock time', () {
      for (final raw in [
        null,
        '',
        'Sundays 10am',
        '24:00',
        '13:00 PM',
        '9:60',
      ]) {
        expect(startMinutes(raw), isNull, reason: '$raw');
      }
    });
  });

  group('formatServiceSchedule', () {
    test('joins days and normalised time', () {
      expect(formatServiceSchedule('Sundays', '14:00'), 'Sundays · 14:00');
    });

    test('renders whichever half is present', () {
      expect(formatServiceSchedule('Sundays', null), 'Sundays');
      expect(formatServiceSchedule(null, '10:00'), '10:00');
    });

    test('is null when nothing is set, so callers can omit the row', () {
      expect(formatServiceSchedule(null, null), isNull);
      expect(formatServiceSchedule('', ''), isNull);
    });
  });
}
