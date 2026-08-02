import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp, FieldValue, FieldPath } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { getMessaging } from 'firebase-admin/messaging';
import { SermonDoc, NewsDoc } from './types';

// Initialize Firebase Admin once at module load
initializeApp();

// Re-export scheduled functions
export { syncSoundCloud } from './sync-soundcloud';
export { syncYouTube, searchYouTube } from './sync-youtube';
export { feedProxy } from './feed-proxy';

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

/**
 * HTTP: GET /getAnnouncements
 * Query params:
 *   - limit: number (max 50, default 20)
 * Returns recent announcements from the `news` collection (newest first).
 * Clients filter by branch; an item with no `branch` is global.
 */
export const getAnnouncements = onRequest(
  { memory: '256MiB', timeoutSeconds: 30, cors: true },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const db = getFirestore();
    const { limit: limitParam } = req.query as Record<string, string>;
    const limit = Math.min(
      parseInt(limitParam || String(ANNOUNCEMENT_PAGE_SIZE), 10) ||
        ANNOUNCEMENT_PAGE_SIZE,
      50
    );
    const snapshot = await db
      .collection('news')
      .orderBy('publishedAt', 'desc')
      .limit(limit)
      .get();

    const announcements = snapshot.docs.map((doc) => {
      const data = doc.data() as NewsDoc;
      const publishedAt =
        data.publishedAt instanceof Timestamp
          ? data.publishedAt.toDate().toISOString()
          : null;
      return {
        id: doc.id,
        title: data.title ?? '',
        body: data.body ?? '',
        type: data.type ?? 'Announcement',
        branch: data.branch ?? null,
        imageUrl: data.imageUrl ?? null,
        publishedAt,
      };
    });

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
 * or `all` (global) — topic names mirror the app's subscriptions
 * (`branch_<slug(branchName)>` / `all`). Idempotent via the `pushedAt` marker;
 * only the last 15 minutes are considered, so it never blasts the backlog.
 * Invoked every minute by Cloud Scheduler.
 */
export const pushPendingAnnouncements = onRequest(
  { memory: '256MiB', timeoutSeconds: 60, cors: true },
  async (_req, res) => {
    const db = getFirestore();
    const cutoff = Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);
    const snap = await db
      .collection('news')
      .orderBy('publishedAt', 'desc')
      .limit(25)
      .get();

    const pending = snap.docs.filter((d) => {
      const data = d.data() as NewsDoc & { pushedAt?: Timestamp };
      if (data.pushedAt) return false;
      const pub = data.publishedAt;
      return pub instanceof Timestamp && pub.toMillis() >= cutoff.toMillis();
    });

    let pushed = 0;
    for (const doc of pending) {
      const data = doc.data() as NewsDoc;
      const branch = (data.branch ?? '').toString().trim();
      // Slug MUST match the app's _slug (branch name -> FCM topic suffix).
      const topic = branch
        ? `branch_${branch.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-')}`
        : 'all';
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

    res.status(200).json({
      pushed,
      considered: pending.length,
      timestamp: Timestamp.now().toDate().toISOString(),
    });
  }
);

const EVENT_PAGE_SIZE = 50;
const API_CACHE_CONTROL = 'public, max-age=300';

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
 *   - limit: number (max 50, default 50)
 * Returns upcoming events (startTime >= now) ordered by startTime asc.
 */
export const getEvents = onRequest(
  { memory: '256MiB', timeoutSeconds: 30, cors: true },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const db = getFirestore();
    const { branch, limit: limitParam } = req.query as Record<string, string>;
    const limit = Math.min(
      parseInt(limitParam || String(EVENT_PAGE_SIZE), 10) || EVENT_PAGE_SIZE,
      50
    );
    const now = Timestamp.now();

    const baseQuery = () =>
      db
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
          return aStart.toMillis() - bStart.toMillis();
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

    res.set('Cache-Control', API_CACHE_CONTROL);
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

/**
 * HTTP: GET /getDailyReading
 * Query params:
 *   - date: YYYY-MM-DD (default: today in Europe/London)
 *   - month: YYYY-MM (returns all readings in that month, ordered by date asc)
 * Doc IDs in `dailyContent` are YYYY-MM-DD.
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

    const toReading = (id: string, data: FirebaseFirestore.DocumentData) => ({
      date: id,
      reading: {
        book: data.reading?.book ?? '',
        chapter: data.reading?.chapter ?? 0,
        verse: data.reading?.verse ?? '',
      },
      prayer: data.prayer ?? '',
      prayerReference: data.prayerReference ?? '',
    });

    let readings;
    if (month) {
      const snapshot = await db
        .collection('dailyContent')
        .where(FieldPath.documentId(), '>=', `${month}-01`)
        .where(FieldPath.documentId(), '<=', `${month}-31`)
        .orderBy(FieldPath.documentId(), 'asc')
        .get();
      readings = snapshot.docs.map((doc) => toReading(doc.id, doc.data()));
    } else {
      const docId = date || todayInLondon();
      const doc = await db.collection('dailyContent').doc(docId).get();
      readings = doc.exists ? [toReading(doc.id, doc.data() ?? {})] : [];
    }

    res.set('Cache-Control', API_CACHE_CONTROL);
    res.status(200).json({
      readings,
      count: readings.length,
    });
  }
);
