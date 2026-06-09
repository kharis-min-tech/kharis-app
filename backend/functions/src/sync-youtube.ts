import { onSchedule } from 'firebase-functions/v2/scheduler';
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
        title: snippet.title.trim(),
        speaker: 'David Antwi',
        description: snippet.description.trim(),
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
