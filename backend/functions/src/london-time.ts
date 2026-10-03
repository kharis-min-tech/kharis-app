// Europe/London wall-clock helpers. Pure: no Firebase imports, so the modules
// that schedule by church time (service reminders, website event import) can
// be exercised on their own.

export const LONDON = 'Europe/London';

const londonParts = new Intl.DateTimeFormat('en-GB', {
  timeZone: LONDON,
  hourCycle: 'h23',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  weekday: 'short',
});

/** London wall-clock fields of the instant [ms]. */
export interface LondonClock {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  /** 0 = Sunday ... 6 = Saturday. */
  weekday: number;
  /** `YYYY-MM-DD`. */
  dateKey: string;
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export function londonClock(ms: number): LondonClock {
  const parts: Record<string, string> = {};
  for (const p of londonParts.formatToParts(new Date(ms))) parts[p.type] = p.value;
  const year = parseInt(parts.year, 10);
  const month = parseInt(parts.month, 10);
  const day = parseInt(parts.day, 10);
  return {
    year,
    month,
    day,
    hour: parseInt(parts.hour, 10),
    minute: parseInt(parts.minute, 10),
    weekday: WEEKDAYS.indexOf(parts.weekday),
    dateKey: `${parts.year}-${parts.month}-${parts.day}`,
  };
}

/** Minutes London is ahead of UTC at the instant [ms] (0 or 60). */
function londonOffsetMinutes(ms: number): number {
  const c = londonClock(ms);
  const asUtc = Date.UTC(c.year, c.month - 1, c.day, c.hour, c.minute);
  return Math.round((asUtc - Math.floor(ms / 60_000) * 60_000) / 60_000);
}

/**
 * The UTC instant at which London's wall clock reads [year]-[month]-[day]
 * [hour]:[minute]. `month` is 1-based; day/hour overflow normalises like
 * `Date.UTC`, so `day + 1` is "tomorrow".
 */
export function londonWallTime(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute = 0,
): number {
  const guess = Date.UTC(year, month - 1, day, hour, minute);
  const first = guess - londonOffsetMinutes(guess) * 60_000;
  // Re-check at the corrected instant: near a BST switch the offset at the
  // guess can differ from the offset at the answer.
  return guess - londonOffsetMinutes(first) * 60_000;
}

/** Today's date as `YYYY-MM-DD` in Europe/London. */
export function todayInLondon(nowMs = Date.now()): string {
  return londonClock(nowMs).dateKey;
}
