// Service reminders: when each campus's next service starts, from the free-text
// `meetingDays` / `meetingTime` fields the Content Studio writes on a branch.
// Pure, so the parsing and London-time arithmetic can be exercised directly;
// the scheduled sender lives in content-notifications.ts.

import { londonClock, londonWallTime } from './london-time';

/** How long before a service the reminder goes out. */
export const REMINDER_LEAD_MS = 60 * 60 * 1000;

/** How often the reminder job runs; also the width of its "due" window. */
export const REMINDER_RUN_EVERY_MS = 15 * 60 * 1000;

/** Weekday words an admin writes, singular form, -> 0 = Sunday ... 6. */
const DAY_WORDS: Record<string, number> = {
  sunday: 0, sun: 0,
  monday: 1, mon: 1,
  tuesday: 2, tue: 2, tues: 2,
  wednesday: 3, wed: 3,
  thursday: 4, thu: 4, thur: 4, thurs: 4,
  friday: 5, fri: 5,
  saturday: 6, sat: 6,
};

/**
 * Weekdays (0 = Sunday) named in [meetingDays], e.g. `Sundays`,
 * `Sundays & Thursdays`, `Sun, Wed`. Empty when none can be read: such a
 * campus gets no reminder rather than a wrong one.
 */
export function parseMeetingDays(meetingDays: unknown): number[] {
  const words = (meetingDays ?? '').toString().toLowerCase().match(/[a-z]+/g) ?? [];
  const days = new Set<number>();
  for (const word of words) {
    const day = DAY_WORDS[word.endsWith('days') ? word.slice(0, -1) : word];
    if (typeof day === 'number') days.add(day);
  }
  return [...days].sort();
}

/**
 * `{hour, minute}` of a single clock time: the web Studio's 24-hour `14:00`
 * (or `14:00:00`) or the app's `2:00 PM`. Null for anything else, including
 * several times (`10am & 6pm`), which cannot be reminded about unambiguously.
 */
export function parseMeetingTime(raw: unknown): { hour: number; minute: number } | null {
  const value = (raw ?? '').toString().trim().toLowerCase();
  const h24 = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(value);
  if (h24) {
    const hour = parseInt(h24[1], 10);
    const minute = parseInt(h24[2], 10);
    return hour <= 23 && minute <= 59 ? { hour, minute } : null;
  }
  const h12 = /^(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?$/.exec(value);
  if (!h12) return null;
  const hour12 = parseInt(h12[1], 10);
  const minute = h12[2] ? parseInt(h12[2], 10) : 0;
  if (hour12 < 1 || hour12 > 12 || minute > 59) return null;
  return { hour: (hour12 % 12) + (h12[3] === 'p' ? 12 : 0), minute };
}

export interface DueService {
  /** Service start instant (ms). */
  startMs: number;
  /** London date of the service, `YYYY-MM-DD`: the once-per-day claim key. */
  dateKey: string;
}

/**
 * The service whose reminder falls due in this run: one starting within
 * `(now + lead - runEvery, now + lead]`. Consecutive runs every
 * [REMINDER_RUN_EVERY_MS] tile time exactly, so each service is picked by one
 * run; the per-date claim makes a retried run harmless.
 */
export function dueService(
  meetingDays: unknown,
  meetingTime: unknown,
  nowMs: number,
): DueService | null {
  const days = parseMeetingDays(meetingDays);
  const time = parseMeetingTime(meetingTime);
  if (days.length === 0 || !time) return null;

  const windowEnd = nowMs + REMINDER_LEAD_MS;
  const windowStart = windowEnd - REMINDER_RUN_EVERY_MS;
  const today = londonClock(nowMs);
  // The window is at most ~1h15 ahead, so today and tomorrow cover it.
  for (const offset of [0, 1]) {
    const startMs = londonWallTime(
      today.year, today.month, today.day + offset, time.hour, time.minute,
    );
    const clock = londonClock(startMs);
    if (!days.includes(clock.weekday)) continue;
    if (startMs > windowStart && startMs <= windowEnd) {
      return { startMs, dateKey: clock.dateKey };
    }
  }
  return null;
}
