import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest } from 'firebase-functions/v2/https';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { defineString } from 'firebase-functions/params';
import {
  SermonDoc,
  YouTubeSearchItem,
  YouTubeSearchResponse,
  YouTubeVideoDetails,
  YouTubeVideosResponse,
} from './types';

// Direct channel ID — more reliable than handle/username lookup
const CHANNEL_ID = 'UC4l8WmdF9ivMDQHHVOdYKqQ';
const YT_API_BASE = 'https://www.googleapis.com/youtube/v3';
const youtubeApiKey = defineString('YOUTUBE_API_KEY');

/**
 * Converts ISO 8601 duration (e.g. "PT4M13S", "PT1H2M3S") to seconds.
 */
function iso8601ToSeconds(duration: string): number {
  const match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return 0;
  const h = parseInt(match[1] || '0', 10);
  const m = parseInt(match[2] || '0', 10);
  const s = parseInt(match[3] || '0', 10);
  return h * 3600 + m * 60 + s;
}

/**
 * YouTube API strings arrive HTML-entity-encoded (&#39; &amp; &quot; …).
 * Decode them once at the boundary so Firestore stores clean text.
 */
function decodeHtmlEntities(s: string): string {
  return s
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(parseInt(n, 10)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ');
}

async function fetchLatestVideos(
  apiKey: string,
  channelId: string,
  maxResults = 50
): Promise<YouTubeSearchItem[]> {
  const url =
    `${YT_API_BASE}/search?part=id,snippet` +
    `&channelId=${channelId}` +
    `&order=date` +
    `&type=video` +
    `&maxResults=${maxResults}` +
    `&key=${apiKey}`;
  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`YouTube search failed: ${res.status} — ${body}`);
  }
  const data = (await res.json()) as YouTubeSearchResponse;
  return data.items ?? [];
}

async function fetchVideoDetails(
  apiKey: string,
  videoIds: string[]
): Promise<Map<string, number>> {
  if (videoIds.length === 0) return new Map();
  const ids = videoIds.join(',');
  const url = `${YT_API_BASE}/videos?part=contentDetails&id=${ids}&key=${apiKey}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Video details fetch failed: ${res.status}`);
  const data = (await res.json()) as YouTubeVideosResponse;
  const durationMap = new Map<string, number>();
  for (const item of data.items as YouTubeVideoDetails[]) {
    durationMap.set(item.id, iso8601ToSeconds(item.contentDetails.duration));
  }
  return durationMap;
}

export const syncYouTube = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: 'America/New_York',
    memory: '256MiB',
    timeoutSeconds: 120,
  },
  async () => {
    const db = getFirestore();
    const apiKey = youtubeApiKey.value();
    if (!apiKey) {
      console.error('YOUTUBE_API_KEY not configured — skipping YouTube sync');
      return;
    }

    // Use the channel ID directly
    const channelId = CHANNEL_ID;

    // Fetch latest videos
    let videos: YouTubeSearchItem[];
    try {
      videos = await fetchLatestVideos(apiKey, channelId);
    } catch (err) {
      console.error('Failed to fetch YouTube videos:', err);
      throw err;
    }

    if (videos.length === 0) {
      console.log('No YouTube videos found');
      return;
    }

    // Batch-fetch video durations
    const videoIds = videos.map((v) => v.id.videoId);
    let durationMap: Map<string, number>;
    try {
      durationMap = await fetchVideoDetails(apiKey, videoIds);
    } catch (err) {
      console.warn('Failed to fetch video durations, defaulting to 0:', err);
      durationMap = new Map();
    }

    const batch = db.batch();
    const sermonsRef = db.collection('sermons');

    for (const video of videos) {
      const videoId = video.id.videoId;
      // Deduplicate by videoId
      const docRef = sermonsRef.doc(`yt_${videoId}`);
      const snippet = video.snippet;
      const thumbnail =
        snippet.thumbnails.high?.url ?? snippet.thumbnails.default?.url;

      const sermon: Omit<SermonDoc, 'id' | 'createdAt'> & {
        createdAt: FieldValue;
        updatedAt: Timestamp;
      } = {
        title: decodeHtmlEntities(snippet.title.trim()),
        speaker: 'David Antwi',
        description: decodeHtmlEntities(snippet.description.trim()),
        audioUrl: '',
        videoId,
        thumbnailUrl: thumbnail,
        duration: durationMap.get(videoId) ?? 0,
        publishedAt: Timestamp.fromDate(new Date(snippet.publishedAt)),
        source: 'youtube',
        type: 'video',
        playCount: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: Timestamp.fromDate(new Date()),
      };

      const cleanSermon = Object.fromEntries(
        Object.entries(sermon).filter(([, v]) => v !== undefined && v !== '')
      );

      batch.set(docRef, cleanSermon, { merge: true });
    }

    await batch.commit();
    console.log(`YouTube sync complete: ${videos.length} videos upserted`);
  }
);

/**
 * Admin-only live search over the whole Kharis Church YouTube channel.
 *
 * The Content Studio calls this to browse/search ALL channel uploads (not just
 * the synced subset) and feature any video. Gated to admins because every
 * search spends 100 units of the YouTube API daily quota.
 *
 * GET ?q=<text>&pageToken=<token>&limit=<n<=50>
 * -> { videos: [{ videoId, title, description, thumbnailUrl, publishedAt,
 *      duration, inLibrary, isFeatured }], nextPageToken, totalResults, count }
 */
export const searchYouTube = onRequest(
  { cors: true, memory: '256MiB', timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    // Admin gate: Firebase ID token + users/{uid}.role == 'admin'.
    try {
      const authz = String(req.headers.authorization ?? '');
      const idToken = authz.startsWith('Bearer ') ? authz.slice(7) : '';
      const decoded = await getAuth().verifyIdToken(idToken);
      const profile = await getFirestore().doc(`users/${decoded.uid}`).get();
      if (profile.get('role') !== 'admin' && decoded.admin !== true) {
        res.status(403).json({ error: 'Admin only' });
        return;
      }
    } catch {
      res.status(401).json({ error: 'Sign-in required' });
      return;
    }

    const apiKey = youtubeApiKey.value();
    if (!apiKey) {
      res.status(500).json({ error: 'YOUTUBE_API_KEY not configured' });
      return;
    }

    const q = String(req.query.q ?? '').trim();
    const pageToken = String(req.query.pageToken ?? '').trim();
    const limitParam = parseInt(String(req.query.limit ?? ''), 10);
    const limit = Math.min(Number.isFinite(limitParam) && limitParam > 0 ? limitParam : 25, 50);

    const url =
      `${YT_API_BASE}/search?part=id,snippet` +
      `&channelId=${CHANNEL_ID}` +
      `&type=video` +
      `&maxResults=${limit}` +
      `&order=${q ? 'relevance' : 'date'}` +
      (q ? `&q=${encodeURIComponent(q)}` : '') +
      (pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : '') +
      `&key=${apiKey}`;

    const ytRes = await fetch(url);
    if (!ytRes.ok) {
      res.status(502).json({ error: `YouTube API error ${ytRes.status}` });
      return;
    }
    const data = (await ytRes.json()) as YouTubeSearchResponse & {
      pageInfo?: { totalResults?: number };
    };
    const items = (data.items ?? []).filter((v) => v.id?.videoId);
    const ids = items.map((v) => v.id.videoId);

    let durations = new Map<string, number>();
    try {
      if (ids.length) durations = await fetchVideoDetails(apiKey, ids);
    } catch {
      // Durations are cosmetic; carry on without them.
    }

    // Overlay library/featured state so the studio can show what's already in.
    const db = getFirestore();
    const snaps = ids.length
      ? await db.getAll(...ids.map((id) => db.doc(`sermons/yt_${id}`)))
      : [];
    const lib = new Map(
      snaps.map((s) => [s.id, s.exists ? s.get('isFeatured') === true : null])
    );

    res.set('Cache-Control', 'private, no-store');
    res.status(200).json({
      videos: items.map((v) => ({
        videoId: v.id.videoId,
        title: decodeHtmlEntities(v.snippet.title.trim()),
        description: decodeHtmlEntities((v.snippet.description ?? '').trim()),
        thumbnailUrl:
          v.snippet.thumbnails.high?.url ?? v.snippet.thumbnails.default?.url ?? null,
        publishedAt: v.snippet.publishedAt,
        duration: durations.get(v.id.videoId) ?? 0,
        inLibrary: lib.get(`yt_${v.id.videoId}`) !== null && lib.has(`yt_${v.id.videoId}`),
        isFeatured: lib.get(`yt_${v.id.videoId}`) === true,
      })),
      nextPageToken: data.nextPageToken ?? null,
      totalResults: data.pageInfo?.totalResults ?? null,
      count: items.length,
    });
  }
);
