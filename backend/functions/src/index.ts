import { initializeApp } from 'firebase-admin/app';
import {
  getFirestore,
  Timestamp,
  FieldValue,
  FieldPath,
  Query,
} from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getMessaging } from 'firebase-admin/messaging';
import { EventDoc, NewsDoc } from './types';
import { branchTopic } from './topics';
import { todayInLondon } from './london-time';
import { NewsRecord, isPushDue, pickAnnouncements } from './announcements';
import { EventRecord, IN_PROGRESS_LOOKBACK_MS, pickEvents } from './events-api';
import {
  DATE_KEY,
  MONTH_KEY,
  PLAN_LOOKBACK,
  PlanEntry,
  ReadingPlanDoc,
  ResolvedReading,
  dayDocReading,
  formatReference,
  planEntry,
  resolveFromPlans,
} from './reading-plans';

// Initialize Firebase Admin once at module load
initializeApp();

// Re-export scheduled functions
export { syncYouTube, searchYouTube } from './sync-youtube';
export { syncWebsiteEvents } from './sync-website-events';
export { feedProxy } from './feed-proxy';
export { sermonApiProxy } from './sermon-proxy';

// Content Studio -> device pushes: Firestore triggers that fire on the write
// itself (events, branch venue details), plus the service reminder schedule.
// See `content-notifications.ts`.
export {
  onEventWritten,
  onBranchVenueWritten,
  pushServiceReminders,
  purgePushLog,
} from './content-notifications';

const ANNOUNCEMENT_PAGE_SIZE = 20;

/** The newest published `news` docs, optionally for one campus. */
async function newestNews(
  db: FirebaseFirestore.Firestore,
  now: Timestamp,
  fetch: number,
  branch?: string,
): Promise<NewsRecord[]> {
  // `publishedAt <= now` in the query itself: Studio-scheduled future notices
  // sort first and would otherwise eat the over-fetch window.
  let query: Query = db.collection('news').where('publishedAt', '<=', now);
  if (branch) query = query.where('branch', '==', branch);
  const snap = await query.orderBy('publishedAt', 'desc').limit(fetch).get();
  return snap.docs.map((d) => ({ id: d.id, data: d.data() as NewsDoc }));
}

/**
 * HTTP: GET /getAnnouncements
 * Query params:
 *   - branch: branch name (optional). When given, returns that branch's
 *     announcements PLUS all-campus ones, mirroring getEvents.
 *   - limit: number (max 50, default 20)
 * Returns live announcements from the `news` collection (newest first):
 * published (`publishedAt <= now`) and not expired. See `pickAnnouncements`.
 */
export const getAnnouncements = onRequest(
  { memory: '256MiB', timeoutSeconds: 30, cors: true },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const { branch, limit: limitParam } = req.query as Record<string, string>;
    const limit = Math.min(
      parseInt(limitParam || String(ANNOUNCEMENT_PAGE_SIZE), 10) ||
        ANNOUNCEMENT_PAGE_SIZE,
      50
    );
    const db = getFirestore();
    const now = Timestamp.now();
    // Over-fetch so the post-filter for expired items still fills the page.
    const fetch = Math.min(limit * 2, 100);
    const [branchDocs, anyDocs] = await Promise.all([
      branch ? newestNews(db, now, fetch, branch) : Promise.resolve([]),
      newestNews(db, now, fetch),
    ]);
    const announcements = pickAnnouncements(
      branch,
      branchDocs,
      anyDocs,
      limit,
      now.toMillis(),
    );

    res.status(200).json({
      announcements,
      count: announcements.length,
      timestamp: now.toDate().toISOString(),
    });
  }
);

const PUSH_WINDOW_MS = 15 * 60 * 1000;

/**
 * Push pending announcements. Finds recently-published `news` docs that haven't
 * been pushed and sends an FCM notification to the branch topic (branch-scoped)
 * or `all` (all-campus) — topic names mirror the app's subscriptions
 * (`branch_<slug(branchName)>` / `all`), and the topic is derived from the very
 * same `branch` field getAnnouncements scopes on, so an announcement is pushed
 * to exactly the audience that can later read it back. Idempotent via the
 * `pushedAt` marker; only the last 15 minutes are considered, so it never
 * blasts the backlog.
 *
 * A Studio-scheduled notice (future `publishedAt`) is pushed when its time
 * arrives, not when it is saved: the query and `isPushDue` both require
 * `publishedAt <= now`, the same rule getAnnouncements serves by.
 *
 * Scheduled every minute, which is what keeps the 15-minute window meaningful:
 * an announcement is picked up within a minute of publishing, and one bad run
 * still leaves 14 minutes of retries before a doc ages out.
 */
export const pushPendingAnnouncements = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: 'Europe/London',
    memory: '256MiB',
    timeoutSeconds: 60,
  },
  async () => {
    const db = getFirestore();
    const now = Timestamp.now();
    const nowMs = now.toMillis();
    const snap = await db
      .collection('news')
      .where('publishedAt', '<=', now)
      .where('publishedAt', '>=', Timestamp.fromMillis(nowMs - PUSH_WINDOW_MS))
      .orderBy('publishedAt', 'desc')
      .limit(25)
      .get();

    const pending = snap.docs.filter((d) =>
      isPushDue(d.data() as NewsDoc & { pushedAt?: unknown }, nowMs, PUSH_WINDOW_MS),
    );

    let pushed = 0;
    for (const doc of pending) {
      const data = doc.data() as NewsDoc;
      // `branch` is the exact field getAnnouncements scopes on; blank/absent
      // means all-campus, which branchTopic maps to the `all` topic.
      const branch = (data.branch ?? '').toString().trim();
      const topic = branchTopic(branch);
      const title = data.title || 'Kharis';
      const body =
        (data.body && data.body.length > 140
          ? `${data.body.slice(0, 137)}...`
          : data.body) || 'New announcement';
      const eventId = (data.eventId ?? '').toString().trim();
      try {
        const id = await getMessaging().send({
          topic,
          notification: { title, body },
          data: {
            type: 'announcement',
            newsId: doc.id,
            branch,
            ...(eventId ? { eventId } : {}),
          },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        });
        await doc.ref.set(
          { pushedAt: FieldValue.serverTimestamp(), pushTopic: topic, pushMessageId: id },
          { merge: true },
        );
        pushed++;
        console.log(`[push] ${doc.id} -> ${topic} (${id})`);
      } catch (e) {
        console.error(`[push] failed for ${doc.id} topic ${topic}:`, e);
        await doc.ref
          .set({ pushError: String(e) }, { merge: true })
          .catch(() => undefined);
      }
    }

    console.log(
      `[push] pushed ${pushed}/${pending.length} pending announcement(s)`,
    );
  },
);

const EVENT_PAGE_SIZE = 50;
const API_CACHE_CONTROL = 'public, max-age=300';
// Past events are a "moving window" — an event crosses from upcoming to past
// the moment it finishes, so the past variant is cached far more briefly than
// the rest of the read API. The `when` query param is part of the CDN cache
// key, so the two variants can never be served from each other's entry.
const EVENT_PAST_CACHE_CONTROL = 'public, max-age=60';
// The Past tab is a capped archive, not a full history: only the 15 most
// recent finished events are ever served. Older events stay in Firestore,
// they are simply out of view — which also bounds what the past query costs.
const PAST_EVENT_LIMIT = 15;

/**
 * HTTP: GET /getBranches
 * Returns all branches (venues) ordered by `order` asc, doc fields verbatim.
 */
export const getBranches = onRequest(
  { memory: '256MiB', timeoutSeconds: 30, cors: true },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const db = getFirestore();
    const snapshot = await db
      .collection('branches')
      .orderBy('order', 'asc')
      .get();

    const branches = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.set('Cache-Control', API_CACHE_CONTROL);
    res.status(200).json({
      branches,
      count: branches.length,
    });
  }
);

/** How many docs the all-campus half of a branch-scoped view reads. */
const ALL_CAMPUS_EVENT_WINDOW = 200;

/**
 * HTTP: GET /getEvents
 * Query params:
 *   - branch: branch name (optional). When given, includes events for that
 *     branch OR all-campus events (null, blank or absent `branch`).
 *   - when: 'upcoming' (default) | 'past'
 *   - limit: number. Upcoming: default and max 50. Past: PAST_EVENT_LIMIT is
 *     both the default and the ceiling — a larger `limit` is clamped, so no
 *     caller can widen the past archive beyond the 15 most recent.
 * Upcoming = not yet finished (effective end >= now, reaching back
 * IN_PROGRESS_LOOKBACK_MS so a running event stays listed), soonest first.
 * Past = finished, most recent first. Same rules as the app's Firestore
 * stream, so the list does not change when one source replaces the other.
 */
export const getEvents = onRequest(
  { memory: '256MiB', timeoutSeconds: 30, cors: true },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const db = getFirestore();
    const {
      branch,
      limit: limitParam,
      when,
    } = req.query as Record<string, string>;
    const past = when === 'past';
    const maxLimit = past ? PAST_EVENT_LIMIT : EVENT_PAGE_SIZE;
    const limit = Math.min(parseInt(limitParam, 10) || maxLimit, maxLimit);
    const nowMs = Date.now();
    // Over-fetch: running events sit in both windows and are dropped from one.
    const fetch = Math.min(limit * 2, 100);

    const window = async (size: number, campus?: string): Promise<EventRecord[]> => {
      let query: Query = db.collection('events');
      if (campus) query = query.where('branch', '==', campus);
      query = past
        ? query
            .where('startTime', '<', Timestamp.fromMillis(nowMs))
            .orderBy('startTime', 'desc')
        : query
            .where('startTime', '>=', Timestamp.fromMillis(nowMs - IN_PROGRESS_LOOKBACK_MS))
            .orderBy('startTime', 'asc');
      const snap = await query.limit(size).get();
      return snap.docs.map((d) => ({ id: d.id, data: d.data() as EventDoc }));
    };

    // The all-campus half is read unfiltered and picked in memory: an
    // equality filter on `branch == null` misses docs with no `branch` key.
    const [branchDocs, anyDocs] = await Promise.all([
      branch ? window(fetch, branch) : Promise.resolve([]),
      window(branch ? ALL_CAMPUS_EVENT_WINDOW : fetch),
    ]);
    const events = pickEvents(branch, branchDocs, anyDocs, past, limit, nowMs);

    res.set('Cache-Control', past ? EVENT_PAST_CACHE_CONTROL : API_CACHE_CONTROL);
    res.status(200).json({
      events,
      count: events.length,
    });
  }
);

/** FCM topic for the daily reading — mirrors the app's `KharisTopics.dailyReading`. */
const DAILY_READING_TOPIC = 'daily_reading';

/**
 * Plans that had already started on or before [date], newest start first.
 * Single-field range + order, so no composite index is required.
 */
async function loadPlans(
  db: FirebaseFirestore.Firestore,
  date: string,
): Promise<PlanEntry[]> {
  const snapshot = await db
    .collection('readingPlans')
    .where('startDate', '<=', date)
    .orderBy('startDate', 'desc')
    .limit(PLAN_LOOKBACK)
    .get();

  const entries: PlanEntry[] = [];
  for (const doc of snapshot.docs) {
    const entry = planEntry(doc.id, doc.data() as ReadingPlanDoc);
    if (entry) entries.push(entry);
  }
  return entries;
}

/** The reading for a single date, hand-written day doc first. */
async function resolveReading(
  db: FirebaseFirestore.Firestore,
  date: string,
): Promise<ResolvedReading | null> {
  const doc = await db.collection('dailyContent').doc(date).get();
  const data = doc.exists ? doc.data() ?? {} : null;
  if (data?.reading?.book) return dayDocReading(date, data);
  return resolveFromPlans(await loadPlans(db, date), date);
}

/** Every resolvable reading in `YYYY-MM`, date ascending. */
async function resolveMonth(
  db: FirebaseFirestore.Firestore,
  month: string,
): Promise<ResolvedReading[]> {
  const [year, monthIndex] = month.split('-').map((p) => parseInt(p, 10));
  const dayCount = new Date(Date.UTC(year, monthIndex, 0)).getUTCDate();
  const lastDate = `${month}-${String(dayCount).padStart(2, '0')}`;

  const [daySnapshot, plans] = await Promise.all([
    db
      .collection('dailyContent')
      .where(FieldPath.documentId(), '>=', `${month}-01`)
      .where(FieldPath.documentId(), '<=', lastDate)
      .orderBy(FieldPath.documentId(), 'asc')
      .get(),
    loadPlans(db, lastDate),
  ]);

  const dayDocs = new Map(daySnapshot.docs.map((doc) => [doc.id, doc.data()]));
  const readings: ResolvedReading[] = [];
  for (let day = 1; day <= dayCount; day++) {
    const date = `${month}-${String(day).padStart(2, '0')}`;
    const data = dayDocs.get(date);
    if (data?.reading?.book) {
      readings.push(dayDocReading(date, data));
      continue;
    }
    const resolved = resolveFromPlans(plans, date);
    if (resolved) readings.push(resolved);
  }
  return readings;
}

/**
 * HTTP: GET /getDailyReading
 * Query params:
 *   - date: YYYY-MM-DD (default: today in Europe/London)
 *   - month: YYYY-MM (returns every resolvable reading in that month, date asc)
 *
 * Each reading carries `source` (`day` | `plan` | `plan-last-day`) and the
 * originating `planId`/`planTitle` so the Content Studio can show an admin
 * exactly why a date resolves the way it does.
 */
export const getDailyReading = onRequest(
  { memory: '256MiB', timeoutSeconds: 30, cors: true },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const db = getFirestore();
    const { date, month } = req.query as Record<string, string>;

    if (month && !MONTH_KEY.test(month)) {
      res.status(400).json({ error: 'month must be YYYY-MM' });
      return;
    }
    if (date && !DATE_KEY.test(date)) {
      res.status(400).json({ error: 'date must be YYYY-MM-DD' });
      return;
    }

    let readings: ResolvedReading[];
    if (month) {
      readings = await resolveMonth(db, month);
    } else {
      const resolved = await resolveReading(db, date || todayInLondon());
      readings = resolved ? [resolved] : [];
    }

    res.set('Cache-Control', API_CACHE_CONTROL);
    res.status(200).json({
      readings,
      count: readings.length,
    });
  }
);

/**
 * Daily reading notification. Fires once a day at 07:00 Europe/London and
 * pushes the resolved reading to the `daily_reading` topic — the same topic the
 * app's notification preference toggles, so opting out really opts out.
 *
 * Idempotency: `dailyReadingPushes/{YYYY-MM-DD}` is CLAIMED in a transaction
 * before the send, so a re-run (scheduler retry, redeploy, manual trigger) can
 * never send twice for one date. A failed send records `pushError` on the claim
 * instead of releasing it: a missed day can be fixed by hand, a duplicate blast
 * to the whole church cannot be taken back.
 */
export const pushDailyReading = onSchedule(
  {
    schedule: '0 7 * * *',
    timeZone: 'Europe/London',
    memory: '256MiB',
    timeoutSeconds: 60,
  },
  async () => {
    const db = getFirestore();
    const date = todayInLondon();
    const marker = db.collection('dailyReadingPushes').doc(date);

    const claimed = await db.runTransaction(async (tx) => {
      const existing = await tx.get(marker);
      if (existing.exists) return false;
      tx.set(marker, { date, claimedAt: FieldValue.serverTimestamp() });
      return true;
    });
    if (!claimed) {
      console.log(`[reading-push] ${date} already claimed — skipping`);
      return;
    }

    const resolved = await resolveReading(db, date);
    if (!resolved?.reading.book) {
      await marker.set({ skipped: 'no reading resolved' }, { merge: true });
      console.warn(`[reading-push] no reading resolved for ${date}`);
      return;
    }

    const reference = formatReference(
      resolved.reading.book,
      resolved.reading.chapter,
      resolved.reading.verse,
    );
    try {
      const id = await getMessaging().send({
        topic: DAILY_READING_TOPIC,
        notification: { title: "Today's Bible reading", body: reference },
        // `reading` is the type NotificationService._handleNotificationTap
        // already routes to /reading — do not invent a new string here.
        data: { type: 'reading', date, reference, source: resolved.source },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      await marker.set(
        {
          pushedAt: FieldValue.serverTimestamp(),
          pushMessageId: id,
          reference,
          source: resolved.source,
        },
        { merge: true },
      );
      console.log(`[reading-push] ${date} -> ${reference} (${id})`);
    } catch (e) {
      console.error(`[reading-push] failed for ${date}:`, e);
      await marker
        .set({ pushError: String(e) }, { merge: true })
        .catch(() => undefined);
    }
  },
);

// ─── Birthday pushes ──────────────────────────────────────────────────────────

/**
 * Daily 08:00 London: members whose profile `dob` (yyyy-mm-dd) matches
 * today's month-day get a direct push on their saved device token
 * (`users/{uid}.fcmToken`, written by the app at sign-in/refresh).
 *
 * The users collection is small (tens of docs); when it grows past ~2k,
 * add a `dobMMDD` field at write time and query on it instead of the
 * in-memory filter. A create()-guarded marker in `birthdayPushes/{date}`
 * keeps retried runs idempotent, mirroring the daily-reading worker.
 * Dead tokens are pruned so the next run stays clean.
 */
export const pushBirthdays = onSchedule(
  { schedule: '0 8 * * *', timeZone: 'Europe/London', region: 'us-central1' },
  async () => {
    const db = getFirestore();
    const todayFull = new Date().toLocaleDateString('en-CA', {
      timeZone: 'Europe/London',
    }); // yyyy-mm-dd
    const monthDay = todayFull.slice(5); // mm-dd

    const marker = db.collection('birthdayPushes').doc(todayFull);
    try {
      await marker.create({ claimedAt: FieldValue.serverTimestamp() });
    } catch {
      console.log(`[birthday] ${todayFull} already claimed; skipping`);
      return;
    }

    const snap = await db.collection('users').limit(2000).get();
    const celebrants = snap.docs.filter((d) => {
      const dob = d.data().dob;
      return (
        typeof dob === 'string' &&
        dob.slice(5) === monthDay &&
        typeof d.data().fcmToken === 'string' &&
        d.data().fcmToken.length > 0
      );
    });
    if (celebrants.length === 0) {
      console.log(`[birthday] no celebrants for ${monthDay}`);
      return;
    }

    let sent = 0;
    for (const doc of celebrants) {
      const { fcmToken, displayName } = doc.data() as {
        fcmToken: string;
        displayName?: string;
      };
      const first = (displayName ?? '').trim().split(/\s+/)[0];
      try {
        await getMessaging().send({
          token: fcmToken,
          notification: {
            title: 'Happy birthday! 🎉',
            body: first
              ? `${first}, the whole Kharis family is celebrating you today.`
              : 'The whole Kharis family is celebrating you today.',
          },
          data: { type: 'birthday' },
        });
        sent += 1;
      } catch (err) {
        const code = (err as { code?: string }).code ?? '';
        console.warn(`[birthday] send failed for ${doc.id}: ${code}`);
        if (code.includes('registration-token-not-registered')) {
          await doc.ref.update({ fcmToken: FieldValue.delete() });
        }
      }
    }
    await marker.set(
      { pushedAt: FieldValue.serverTimestamp(), celebrants: celebrants.length, sent },
      { merge: true },
    );
    console.log(`[birthday] sent ${sent}/${celebrants.length} for ${monthDay}`);
  },
);
