import { initializeApp } from 'firebase-admin/app';
import {
  getFirestore,
  Timestamp,
  FieldValue,
  FieldPath,
  QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getMessaging } from 'firebase-admin/messaging';
import { SermonDoc, NewsDoc } from './types';
import { branchTopic } from './topics';
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
export { syncSoundCloud } from './sync-soundcloud';
export { syncYouTube, searchYouTube } from './sync-youtube';
export { feedProxy } from './feed-proxy';

// Content Studio -> device pushes: Firestore triggers that fire on the write
// itself (events, branch venue details). See `content-notifications.ts`.
export {
  onEventWritten,
  onBranchVenueWritten,
  purgePushLog,
} from './content-notifications';

const PAGE_SIZE = 20;

/**
 * HTTP fallback: GET /getSermons
 * Query params:
 *   - source: 'soundcloud' | 'youtube' (optional filter)
 *   - type: 'audio' | 'video' (optional filter)
 *   - after: Firestore document ID to paginate from (optional)
 *   - limit: number (max 50, default 20)
 */
export const getSermons = onRequest(
  {
    memory: '256MiB',
    timeoutSeconds: 30,
    cors: true,
  },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    const db = getFirestore();
    const { source, type, after, limit: limitParam } = req.query as Record<string, string>;

    const limit = Math.min(
      parseInt(limitParam || String(PAGE_SIZE), 10) || PAGE_SIZE,
      50
    );

    let query = db
      .collection('sermons')
      .orderBy('publishedAt', 'desc')
      .limit(limit);

    if (source === 'soundcloud' || source === 'youtube') {
      query = query.where('source', '==', source);
    }

    if (type === 'audio' || type === 'video') {
      query = query.where('type', '==', type);
    }

    if (after) {
      const cursorDoc = await db.collection('sermons').doc(after).get();
      if (cursorDoc.exists) {
        query = query.startAfter(cursorDoc);
      }
    }

    const snapshot = await query.get();

    const sermons: (SermonDoc & { id: string })[] = snapshot.docs.map((doc) => {
      const data = doc.data() as SermonDoc;
      return { ...data, id: doc.id };
    });

    const lastDoc = snapshot.docs[snapshot.docs.length - 1];
    const nextCursor = snapshot.docs.length === limit ? lastDoc?.id : null;

    res.status(200).json({
      sermons,
      nextCursor,
      count: sermons.length,
      timestamp: Timestamp.now().toDate().toISOString(),
    });
  }
);

const ANNOUNCEMENT_PAGE_SIZE = 20;

/** JSON shape returned by getAnnouncements. `branch: null` = all-campus. */
interface AnnouncementJson {
  id: string;
  title: string;
  body: string;
  type: string;
  branch: string | null;
  imageUrl: string | null;
  publishedAt: string | null;
  expiresAt: string | null;
}

function toAnnouncement(doc: QueryDocumentSnapshot): AnnouncementJson {
  const data = doc.data() as NewsDoc;
  const branch = (data.branch ?? '').toString().trim();
  const { publishedAt, expiresAt } = data;
  return {
    id: doc.id,
    title: data.title ?? '',
    body: data.body ?? '',
    // An announcement is a message, never an event. Legacy docs typed 'Event'
    // by the old admin dropdown are surfaced as announcements so nothing in
    // the app can render a `news` doc as a dated, RSVP-able occurrence.
    type: data.type && data.type !== 'Event' ? data.type : 'Announcement',
    branch: branch || null,
    imageUrl: data.imageUrl ?? null,
    publishedAt:
      publishedAt instanceof Timestamp
        ? publishedAt.toDate().toISOString()
        : null,
    // `expiresAt` is written by the web admin portal; null means "never
    // expires". Surfaced so clients reading the Firestore fallback path can
    // apply the same rule.
    expiresAt:
      expiresAt instanceof Timestamp ? expiresAt.toDate().toISOString() : null,
  };
}

const BY_NEWEST = (a: AnnouncementJson, b: AnnouncementJson) =>
  Date.parse(b.publishedAt ?? '') - Date.parse(a.publishedAt ?? '');

/**
 * The announcements a member at [branch] should see, newest first.
 *
 * Branch-scoped notices are selected BEFORE all-campus ones and only then is
 * the page re-sorted for display. That ordering is the whole point of the
 * function: a campus notice is the most relevant thing a member can be shown,
 * so it must never be crowded off the page by newer church-wide items — which
 * is exactly how a branch's announcement used to disappear.
 *
 * Passing no [branch] returns the plain church-wide feed.
 */
async function selectAnnouncements(
  db: FirebaseFirestore.Firestore,
  branch: string | undefined,
  limit: number
): Promise<AnnouncementJson[]> {
  // Over-fetch so the post-filter for expired items still fills the page.
  const newest = () =>
    db
      .collection('news')
      .orderBy('publishedAt', 'desc')
      .limit(Math.min(limit * 2, 100));

  const nowMs = Date.now();
  // Shared expiry rule — an expired notice must not reach any caller.
  const live = (docs: QueryDocumentSnapshot[]) =>
    docs
      .map(toAnnouncement)
      .filter((a) => a.expiresAt === null || Date.parse(a.expiresAt) > nowMs)
      .sort(BY_NEWEST);

  if (!branch) return live((await newest().get()).docs).slice(0, limit);

  // The all-campus half cannot use `where('branch', '==', null)` the way
  // getEvents does: docs created before the portal gained a branch field carry
  // no `branch` key at all, and Firestore equality never matches a missing
  // field. So the second query is unfiltered and the absent/blank branches are
  // picked out in memory.
  const [branchSnap, anySnap] = await Promise.all([
    newest().where('branch', '==', branch).get(),
    newest().get(),
  ]);
  const scoped = live(branchSnap.docs).slice(0, limit);
  const seen = new Set(scoped.map((a) => a.id));
  const campus = live(
    anySnap.docs.filter((d) => {
      const b = (d.data() as NewsDoc).branch;
      return b === null || b === undefined || String(b).trim() === '';
    })
  )
    .filter((a) => !seen.has(a.id))
    .slice(0, limit - scoped.length);

  return [...scoped, ...campus].sort(BY_NEWEST);
}

/**
 * HTTP: GET /getAnnouncements
 * Query params:
 *   - branch: branch name (optional). When given, returns that branch's
 *     announcements PLUS all-campus ones, mirroring getEvents.
 *   - limit: number (max 50, default 20)
 * Returns recent announcements from the `news` collection (newest first),
 * excluding any whose `expiresAt` has passed.
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
    const announcements = await selectAnnouncements(
      getFirestore(),
      branch,
      limit
    );

    res.status(200).json({
      announcements,
      count: announcements.length,
      timestamp: Timestamp.now().toDate().toISOString(),
    });
  }
);

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
    const cutoff = Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);
    const snap = await db
      .collection('news')
      .orderBy('publishedAt', 'desc')
      .limit(25)
      .get();

    const nowMs = Date.now();
    const pending = snap.docs.filter((d) => {
      const data = d.data() as NewsDoc & { pushedAt?: Timestamp };
      if (data.pushedAt) return false;
      // Never push a notice that getAnnouncements would already hide.
      if (data.expiresAt instanceof Timestamp &&
          data.expiresAt.toMillis() <= nowMs) {
        return false;
      }
      const pub = data.publishedAt;
      return pub instanceof Timestamp && pub.toMillis() >= cutoff.toMillis();
    });

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
      try {
        const id = await getMessaging().send({
          topic,
          notification: { title, body },
          data: { type: 'announcement', newsId: doc.id, branch },
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
// the moment it starts, so the past variant is cached far more briefly than
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

/**
 * HTTP: GET /getEvents
 * Query params:
 *   - branch: branch name (optional). When given, includes events for that
 *     branch OR all-campus events (branch == null).
 *   - when: 'upcoming' (default) | 'past'
 *   - limit: number. Upcoming: default and max 50. Past: PAST_EVENT_LIMIT is
 *     both the default and the ceiling — a larger `limit` is clamped, so no
 *     caller can widen the past archive beyond the 15 most recent.
 * Returns upcoming events (startTime >= now) ordered by startTime asc, or
 * past events (startTime < now) ordered by startTime desc.
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
    const now = Timestamp.now();

    const baseQuery = () =>
      past
        ? db
            .collection('events')
            .where('startTime', '<', now)
            .orderBy('startTime', 'desc')
            .limit(limit)
        : db
            .collection('events')
            .where('startTime', '>=', now)
            .orderBy('startTime', 'asc')
            .limit(limit);

    let docs;
    if (branch) {
      // Branch-scoped events plus all-campus events (branch == null).
      const [branchSnap, globalSnap] = await Promise.all([
        baseQuery().where('branch', '==', branch).get(),
        baseQuery().where('branch', '==', null).get(),
      ]);
      docs = [...branchSnap.docs, ...globalSnap.docs]
        .sort((a, b) => {
          const aStart = a.data().startTime as Timestamp;
          const bStart = b.data().startTime as Timestamp;
          const delta = aStart.toMillis() - bStart.toMillis();
          return past ? -delta : delta;
        })
        .slice(0, limit);
    } else {
      const snapshot = await baseQuery().get();
      docs = snapshot.docs;
    }

    const events = docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title ?? '',
        description: data.description ?? null,
        location: data.location ?? null,
        branch: data.branch ?? null,
        imageUrl: data.imageUrl ?? null,
        isFeatured: data.isFeatured ?? false,
        startTime:
          data.startTime instanceof Timestamp
            ? data.startTime.toDate().toISOString()
            : null,
        endTime:
          data.endTime instanceof Timestamp
            ? data.endTime.toDate().toISOString()
            : null,
      };
    });

    res.set('Cache-Control', past ? EVENT_PAST_CACHE_CONTROL : API_CACHE_CONTROL);
    res.status(200).json({
      events,
      count: events.length,
    });
  }
);

/** Today's date as YYYY-MM-DD in Europe/London. */
function todayInLondon(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/London',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

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
