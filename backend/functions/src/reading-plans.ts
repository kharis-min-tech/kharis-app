// ── Daily reading resolution ─────────────────────────────────────────────────
//
// A reading for a date comes from one of two places, in strict priority order:
//
//   1. `dailyContent/{YYYY-MM-DD}` — a hand-written day. This MUST win over
//      any plan so an admin can special-case a single date (Christmas, a guest
//      speaker's text) without disturbing the plan around it. Do not "simplify"
//      this into a plan-first lookup.
//   2. `readingPlans/{planId}` — a plan authored once that spans a date range
//      and advances on its own: Proverbs 1 on day 1, Proverbs 2 on day 2, and
//      so on, with no further admin action. When several plans cover the same
//      date, the most recently STARTING plan wins.
//
// If no plan covers the date, the plan that ended most recently is pinned to
// its own LAST day. That is an explicit product requirement: when a schedule
// runs out and nobody has authored the next one, the reading stays on the final
// day of the old schedule instead of going blank.
//
// Everything in this module is pure — the Firestore reads live in index.ts —
// so the precedence rules can be reasoned about (and exercised) on their own.

const MS_PER_DAY = 86_400_000;

/** How many recently-started plans to consider when resolving a date. */
export const PLAN_LOOKBACK = 25;

export const DATE_KEY = /^\d{4}-\d{2}-\d{2}$/;
export const MONTH_KEY = /^\d{4}-\d{2}$/;

export type ReadingSource = 'day' | 'plan' | 'plan-last-day';

/** A `readingPlans/{planId}` document. */
export interface ReadingPlanDoc {
  title?: string;
  book?: string;
  /** Inclusive first date of the plan, `YYYY-MM-DD`. */
  startDate?: string;
  /** Plan length in days (inclusive of the start date). */
  days?: number;
  /** `chapter`: one chapter per day. `verse`: one verse block per day. */
  mode?: 'chapter' | 'verse';
  startChapter?: number;
  /** `chapter` mode: constant verse range shown each day (default `1-end`). */
  verses?: string | null;
  /** `verse` mode: first verse of day 1. */
  startVerse?: number;
  /** `verse` mode: how many verses each day covers. */
  versesPerDay?: number;
  prayer?: string;
  prayerReference?: string;
}

export interface ResolvedReading {
  date: string;
  reading: { book: string; chapter: number; verse: string };
  prayer: string;
  prayerReference: string;
  source: ReadingSource;
  planId: string | null;
  planTitle: string | null;
}

/** A validated plan with its date range pre-computed. */
export interface PlanEntry {
  id: string;
  data: ReadingPlanDoc;
  /** Day number of `startDate`. */
  start: number;
  days: number;
}

/**
 * `YYYY-MM-DD` -> whole days since the epoch. Deliberately UTC: plan arithmetic
 * is calendar arithmetic, and a DST shift must never move a reading by a day.
 */
export function dayNumber(date: string): number {
  const [y, m, d] = date.split('-').map((part) => parseInt(part, 10));
  return Date.UTC(y, m - 1, d) / MS_PER_DAY;
}

/** Human reference, collapsing the "whole chapter" verse range. */
export function formatReference(
  book: string,
  chapter: number,
  verse: string,
): string {
  if (!book) return '';
  if (!verse || verse === '1-end') return `${book} ${chapter}`;
  return `${book} ${chapter}:${verse}`;
}

/** Builds a [PlanEntry] from a raw document, or `null` when it is unusable. */
export function planEntry(
  id: string,
  data: ReadingPlanDoc,
): PlanEntry | null {
  const startDate = (data.startDate ?? '').toString();
  const days = Math.floor(data.days ?? 0);
  if (!DATE_KEY.test(startDate) || !data.book || days < 1) return null;
  return { id, data, start: dayNumber(startDate), days };
}

/**
 * Resolves day [offset] (0-based) of [entry]. [date] is the date being asked
 * about, which is later than the plan's own day when a reading is pinned.
 */
export function planReading(
  entry: PlanEntry,
  offset: number,
  date: string,
  source: ReadingSource,
): ResolvedReading {
  const plan = entry.data;
  const book = plan.book ?? '';
  const firstChapter = Math.max(1, Math.floor(plan.startChapter ?? 1));

  let chapter: number;
  let verse: string;
  if (plan.mode === 'verse') {
    const perDay = Math.max(1, Math.floor(plan.versesPerDay ?? 1));
    const first = Math.max(1, Math.floor(plan.startVerse ?? 1)) + offset * perDay;
    chapter = firstChapter;
    verse = perDay === 1 ? `${first}` : `${first}-${first + perDay - 1}`;
  } else {
    chapter = firstChapter + offset;
    verse = (plan.verses ?? '').trim() || '1-end';
  }

  const reference = formatReference(book, chapter, verse);
  return {
    date,
    reading: { book, chapter, verse },
    prayer:
      (plan.prayer ?? '').trim() ||
      `Lord, speak to us through ${reference} today.`,
    prayerReference: (plan.prayerReference ?? '').trim() || reference,
    source,
    planId: entry.id,
    planTitle: plan.title ?? null,
  };
}

/** Projects a hand-written `dailyContent` document. */
export function dayDocReading(
  date: string,
  data: FirebaseFirestore.DocumentData,
): ResolvedReading {
  return {
    date,
    reading: {
      book: data.reading?.book ?? '',
      chapter: data.reading?.chapter ?? 0,
      verse: data.reading?.verse ?? '',
    },
    prayer: data.prayer ?? '',
    prayerReference: data.prayerReference ?? '',
    source: 'day',
    planId: null,
    planTitle: null,
  };
}

/**
 * Plan resolution for [date]: the covering plan first, then the pinned last day
 * of the most recently finished plan. [plans] MUST be start-date descending.
 */
export function resolveFromPlans(
  plans: PlanEntry[],
  date: string,
): ResolvedReading | null {
  const day = dayNumber(date);

  // `plans` is start-descending, so the first plan that covers the date is the
  // most recently starting one — the documented precedence rule.
  const covering = plans.find(
    (plan) => day >= plan.start && day <= plan.start + plan.days - 1,
  );
  if (covering) {
    return planReading(covering, day - covering.start, date, 'plan');
  }

  // Graceful expiry (explicit product requirement): pin to the final day of the
  // plan that ended most recently rather than returning nothing.
  let pinned: PlanEntry | null = null;
  let pinnedEnd = -Infinity;
  for (const plan of plans) {
    const end = plan.start + plan.days - 1;
    if (end >= day || end <= pinnedEnd) continue;
    pinned = plan;
    pinnedEnd = end;
  }
  return pinned
    ? planReading(pinned, pinned.days - 1, date, 'plan-last-day')
    : null;
}
