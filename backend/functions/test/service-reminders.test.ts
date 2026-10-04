import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  REMINDER_RUN_EVERY_MS,
  dueService,
  parseMeetingDays,
  parseMeetingTime,
} from '../src/service-reminders';
import { prefAudience } from '../src/topics';
import { londonWallTime } from '../src/london-time';

test('meeting days: plural, abbreviated and combined forms', () => {
  assert.deepEqual(parseMeetingDays('Sundays'), [0]);
  assert.deepEqual(parseMeetingDays('Sundays & Thursdays'), [0, 4]);
  assert.deepEqual(parseMeetingDays('Sun, Wed'), [0, 3]);
  assert.deepEqual(parseMeetingDays('Monthly'), []);
  assert.deepEqual(parseMeetingDays(undefined), []);
});

test('meeting time: 24-hour and 12-hour forms; several times are refused', () => {
  assert.deepEqual(parseMeetingTime('14:00'), { hour: 14, minute: 0 });
  assert.deepEqual(parseMeetingTime('14:00:00'), { hour: 14, minute: 0 });
  assert.deepEqual(parseMeetingTime('2:00 PM'), { hour: 14, minute: 0 });
  assert.deepEqual(parseMeetingTime('12:00 PM'), { hour: 12, minute: 0 });
  assert.deepEqual(parseMeetingTime('10am'), { hour: 10, minute: 0 });
  assert.equal(parseMeetingTime('10am & 6pm'), null);
});

test('a Sunday 10:00 London service is due in exactly one 15-minute run', () => {
  // Sun 4 Oct 2026 is BST: 10:00 London = 09:00Z.
  const service = londonWallTime(2026, 10, 4, 10, 0);
  assert.equal(new Date(service).toISOString(), '2026-10-04T09:00:00.000Z');
  const due: number[] = [];
  for (let t = service - 3 * 3_600_000; t <= service; t += REMINDER_RUN_EVERY_MS) {
    const d = dueService('Sundays', '10:00 AM', t);
    if (d) {
      due.push(t);
      assert.equal(d.startMs, service);
      assert.equal(d.dateKey, '2026-10-04');
    }
  }
  assert.deepEqual(due, [service - 3_600_000]);
});

test('no reminder on other weekdays or for an unreadable schedule', () => {
  const saturdayNine = londonWallTime(2026, 10, 3, 9, 0);
  assert.equal(dueService('Sundays', '10:00', saturdayNine), null);
  assert.equal(dueService('Every week', '10:00', saturdayNine), null);
});

test('GMT dates resolve with no offset', () => {
  // Sun 6 Dec 2026 is GMT: 2:00 PM London = 14:00Z; due at 13:00Z.
  const d = dueService('Sundays', '2:00 PM', Date.UTC(2026, 11, 6, 13, 0));
  assert.equal(d && new Date(d.startMs).toISOString(), '2026-12-06T14:00:00.000Z');
});

test('preference audiences gate on the toggle topic and the campus topic', () => {
  assert.deepEqual(prefAudience('events', 'KP2 London'), {
    condition: "'events' in topics && 'branch_kp2-london' in topics",
  });
  assert.deepEqual(prefAudience('service_reminders', null), {
    condition: "'service_reminders' in topics && 'all' in topics",
  });
});
