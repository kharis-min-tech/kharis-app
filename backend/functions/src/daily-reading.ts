// Today's Bible reading, as the app shows it: the Content Studio (Supabase)
// `daily_entries` row of kind `reading` for the London date, the `app`
// workspace's before the `general` one's. Mirrors the app's
// `DailyContentRepository` (daily_content_repository.dart). Pure: no Firebase
// imports, so the lookup and the push flow are testable on their own.
//
// There is no fallback. When the Studio has no reading for today (no row, the
// table not created yet, the request failing) nothing is pushed: a made-up
// reading is worse than none.

/** Content Studio Supabase project, read over PostgREST. */
export const CONTENT_STUDIO_URL = 'https://cqgyiqxhpxwasogpdghx.supabase.co';

/**
 * Supabase publishable (anon) key. Public by design: it ships in the app
 * (`ApiConfig.supabasePublishableKey`) and in the Studio's web bundle, and
 * row-level security only grants reads of published content.
 */
export const CONTENT_STUDIO_KEY = 'sb_publishable_fT5_NGYsk0Uh4IO_uYfXvg_ZhR8bl7K';

/** Studio workspaces whose daily entries the app shows, most specific first. */
export const READING_WORKSPACES = ['app', 'general'] as const;

/** How long the 07:00 run waits for the Studio before giving up. */
const LOOKUP_TIMEOUT_MS = 15_000;

/** One Studio Daily Reading entry. */
export interface StudioReading {
  title: string;
  /** Free-text scripture reference ("John 3:16-18"), or empty. */
  reference: string;
  workspace: string;
}

/** The lookup's answer: the reading, or why there is none. */
export type ReadingLookup =
  | { reading: StudioReading }
  | { reading: null; reason: string };

function text(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

/** Today's reading among Studio [rows], the app workspace's first. */
export function pickReading(rows: unknown[], date: string): StudioReading | null {
  for (const workspace of READING_WORKSPACES) {
    for (const row of rows) {
      if (!row || typeof row !== 'object') continue;
      const r = row as Record<string, unknown>;
      const title = text(r.title);
      if (
        title === null ||
        r.kind !== 'reading' ||
        r.workspace !== workspace ||
        typeof r.date !== 'string' ||
        !r.date.startsWith(date)
      ) {
        continue;
      }
      return { title, reference: text(r.reference) ?? '', workspace };
    }
  }
  return null;
}

/** The `daily_entries` query for [date]'s readings. */
export function readingQueryUrl(date: string): string {
  const url = new URL(`${CONTENT_STUDIO_URL}/rest/v1/daily_entries`);
  url.searchParams.set('select', '*');
  url.searchParams.set('kind', 'eq.reading');
  url.searchParams.set('date', `eq.${date}`);
  url.searchParams.set('workspace', `in.(${READING_WORKSPACES.join(',')})`);
  return url.toString();
}

/**
 * [date]'s reading from the Studio. Never throws: any failure, including the
 * 404 PostgREST answers while the table does not exist, is "no reading".
 */
export async function fetchStudioReading(
  date: string,
  fetchImpl: typeof fetch = fetch,
): Promise<ReadingLookup> {
  let rows: unknown;
  try {
    const res = await fetchImpl(readingQueryUrl(date), {
      headers: {
        apikey: CONTENT_STUDIO_KEY,
        Authorization: `Bearer ${CONTENT_STUDIO_KEY}`,
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    });
    if (!res.ok) {
      return { reading: null, reason: `Content Studio answered ${res.status}` };
    }
    rows = await res.json();
  } catch (e) {
    return { reading: null, reason: `Content Studio lookup failed: ${String(e)}` };
  }
  if (!Array.isArray(rows)) {
    return { reading: null, reason: 'Content Studio answered a non-array body' };
  }
  const reading = pickReading(rows, date);
  return reading ? { reading } : { reading: null, reason: 'no reading in the Content Studio' };
}

/** The push `pushDailyReading` sends for [date]. */
export interface ReadingPushMessage {
  title: string;
  body: string;
  data: { type: 'reading'; date: string; reference: string };
}

/** Body text: the Studio's reference, else its title. */
export function readingPushMessage(date: string, reading: StudioReading): ReadingPushMessage {
  const reference = reading.reference || reading.title;
  return {
    title: "Today's Bible reading",
    body: reference,
    // `reading` is the type NotificationService routes to /reading.
    data: { type: 'reading', date, reference },
  };
}

/** Side effects of one daily reading run, injected so tests need no Firebase. */
export interface ReadingPushDeps {
  /** Claims [date] once; false when an earlier run already claimed it. */
  claim(): Promise<boolean>;
  lookup(): Promise<ReadingLookup>;
  send(message: ReadingPushMessage): Promise<string>;
  recordSkipped(reason: string): Promise<void>;
  recordSent(messageId: string, reference: string, workspace: string): Promise<void>;
  recordError(error: unknown): Promise<void>;
}

export type ReadingPushOutcome = 'already-claimed' | 'skipped' | 'sent' | 'failed';

/**
 * One 07:00 run: claim the date, look the reading up, send at most once.
 * The claim comes first so a re-run can never send twice; a failed send is
 * recorded, not retried.
 */
export async function runDailyReadingPush(
  date: string,
  deps: ReadingPushDeps,
): Promise<ReadingPushOutcome> {
  if (!(await deps.claim())) {
    console.log(`[reading-push] ${date} already claimed — skipping`);
    return 'already-claimed';
  }

  const lookup = await deps.lookup();
  if (!lookup.reading) {
    await deps.recordSkipped(lookup.reason);
    console.warn(`[reading-push] no reading for ${date}: ${lookup.reason}`);
    return 'skipped';
  }

  const message = readingPushMessage(date, lookup.reading);
  try {
    const id = await deps.send(message);
    await deps.recordSent(id, message.body, lookup.reading.workspace);
    console.log(`[reading-push] ${date} -> ${message.body} (${id})`);
    return 'sent';
  } catch (e) {
    console.error(`[reading-push] failed for ${date}:`, e);
    await deps.recordError(e).catch(() => undefined);
    return 'failed';
  }
}
