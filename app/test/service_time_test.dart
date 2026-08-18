import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/core/utils/service_time.dart';

void main() {
  group('formatServiceTime', () {
    test('converts the web portal 24-hour shape to 12-hour', () {
      // admin/index.html uses <input type="time">, which yields '14:00'.
      expect(formatServiceTime('14:00'), '2:00 PM');
      expect(formatServiceTime('14:00:00'), '2:00 PM');
      expect(formatServiceTime('09:05'), '9:05 AM');
      expect(formatServiceTime('23:59'), '11:59 PM');
    });

    test('handles both noon and midnight without a 0 o\'clock', () {
      expect(formatServiceTime('00:30'), '12:30 AM');
      expect(formatServiceTime('12:00'), '12:00 PM');
    });

    test('leaves the Flutter admin / seed 12-hour shape untouched', () {
      expect(formatServiceTime('2:00 PM'), '2:00 PM');
    });

    test('passes through free text an admin typed by hand', () {
      expect(
        formatServiceTime('Sundays 10am & 6pm'),
        'Sundays 10am & 6pm',
      );
    });

    test('passes through out-of-range clock values rather than wrapping', () {
      expect(formatServiceTime('25:00'), '25:00');
      expect(formatServiceTime('10:99'), '10:99');
    });

    test('trims, and treats blank as unset', () {
      expect(formatServiceTime('  14:00  '), '2:00 PM');
      expect(formatServiceTime(''), isNull);
      expect(formatServiceTime('   '), isNull);
      expect(formatServiceTime(null), isNull);
    });
  });

  group('formatServiceSchedule', () {
    test('joins days and normalised time', () {
      expect(formatServiceSchedule('Sundays', '14:00'), 'Sundays · 2:00 PM');
    });

    test('renders whichever half is present', () {
      expect(formatServiceSchedule('Sundays', null), 'Sundays');
      expect(formatServiceSchedule(null, '10:00'), '10:00 AM');
    });

    test('is null when nothing is set, so callers can omit the row', () {
      expect(formatServiceSchedule(null, null), isNull);
      expect(formatServiceSchedule('', ''), isNull);
    });
  });
}
