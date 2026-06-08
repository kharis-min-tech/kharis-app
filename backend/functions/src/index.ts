import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { SermonDoc } from './types';

// Initialize Firebase Admin once at module load
initializeApp();

// Re-export scheduled functions
export { syncSoundCloud } from './sync-soundcloud';
export { syncYouTube } from './sync-youtube';

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
