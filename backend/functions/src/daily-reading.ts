// Today's Bible reading, as the app shows it: the Content Studio (Supabase)
// `daily_entries` row of kind `reading` for the London date, the `app`
// workspace's before the `general` one's. Mirrors the app's
// `DailyContentRepository` (daily_content_repository.dart). Pure: no Firebase
// imports, so the lookup and the push flow are testable on their own.
//
// There is no fallback. When the Studio has no reading for today (no row, the
// table not created yet, the request failing) nothing is pushed: a made-up
// reading is worse than none. Nor is anything pushed when the reference names
// a book outside the 66-book canon or a chapter that book does not have
// (`bible-chapters.ts`).

import { referenceProblem } from './bible-chapters';
import { APP_WORKSPACES, fetchStudioRows } from './content-studio';
import { PushAudience, READING_AUDIENCES } from './topics';

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
  for (const workspace of APP_WORKSPACES) {
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

/**
 * [date]'s reading from the Studio. Never throws: any failure, including the
 * 404 PostgREST answers while the table does not exist, is "no reading".
 */
export async function fetchStudioReading(
  date: string,
  fetchImpl: typeof fetch = fetch,
): Promise<ReadingLookup> {
  let rows: unknown[];
  try {
    rows = await fetchStudioRows(
      'daily_entries',
      { kind: 'eq.reading', date: `eq.${date}`, workspace: `in.(${APP_WORKSPACES.join(',')})` },
      fetchImpl,
    );
  } catch (e) {
    return { reading: null, reason: e instanceof Error ? e.message : String(e) };
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
  /** Sends [message] to one of [READING_AUDIENCES]; resolves to the FCM message id. */
  send(message: ReadingPushMessage, audience: PushAudience): Promise<string>;
  recordSkipped(reason: string): Promise<void>;
  recordSent(messageId: string, reference: string, workspace: string): Promise<void>;
  recordError(error: unknown): Promise<void>;
}

export type ReadingPushOutcome = 'already-claimed' | 'skipped' | 'sent' | 'failed';

/**
 * One 07:00 run: claim the date, look the reading up, check its reference,
 * send at most once to each of [READING_AUDIENCES]. The claim comes first so
 * a re-run can never send twice; a failed send is recorded, not retried.
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
  const problem = referenceProblem(message.data.reference);
  if (problem) {
    const reason = `invalid reference: ${problem}`;
    await deps.recordSkipped(reason);
    console.warn(`[reading-push] ${date} not sent, ${reason}`);
    return 'skipped';
  }

  // Every audience gets its send, even when another's fails.
  const ids: string[] = [];
  const errors: unknown[] = [];
  await Promise.all(
    READING_AUDIENCES.map((audience) =>
      deps.send(message, audience).then(
        (id) => ids.push(id),
        (e) => errors.push(e),
      ),
    ),
  );
  try {
    if (ids.length > 0) {
      await deps.recordSent(ids.join(','), message.body, lookup.reading.workspace);
      console.log(`[reading-push] ${date} -> ${message.body} (${ids.join(',')})`);
    }
    if (errors.length > 0) throw new Error(errors.map(String).join('; '));
    return 'sent';
  } catch (e) {
    console.error(`[reading-push] failed for ${date}:`, e);
    await deps.recordError(e).catch(() => undefined);
    return 'failed';
  }
}
