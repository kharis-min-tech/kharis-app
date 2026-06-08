import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { XMLParser } from 'fast-xml-parser';
import { RssFeed, RssItem, SermonDoc } from './types';

const RSS_URL =
  'https://feeds.soundcloud.com/users/soundcloud:users:58625221/sounds.rss';

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  isArray: (tagName) => tagName === 'item',
});

/**
 * Converts an itunes:duration string to seconds.
 * Formats: "HH:MM:SS", "MM:SS", or plain seconds integer string.
 */
function parseDuration(raw?: string): number {
  if (!raw) return 0;
  const trimmed = raw.trim();
  if (/^\d+$/.test(trimmed)) return parseInt(trimmed, 10);
  const parts = trimmed.split(':').map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return 0;
}

function extractAudioUrl(item: RssItem): string {
  if (item.enclosure && item.enclosure['@_url']) {
    return item.enclosure['@_url'];
  }
  return '';
}

function extractThumbnail(item: RssItem): string | undefined {
  if (item['itunes:image'] && item['itunes:image']['@_href']) {
    return item['itunes:image']['@_href'];
  }
  return undefined;
}

function extractGuid(item: RssItem): string {
  if (!item.guid) return extractAudioUrl(item);
  if (typeof item.guid === 'string') return item.guid;
  return item.guid['#text'] || extractAudioUrl(item);
}

export const syncSoundCloud = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: 'America/New_York',
    memory: '256MiB',
    timeoutSeconds: 120,
  },
  async () => {
    const db = getFirestore();

    // Fetch RSS feed
    let xmlText: string;
    try {
      const response = await fetch(RSS_URL, {
        headers: { 'User-Agent': 'KharisFunctions/1.0' },
      });
      if (!response.ok) {
        throw new Error(`RSS fetch failed: ${response.status} ${response.statusText}`);
      }
      xmlText = await response.text();
    } catch (err) {
      console.error('Failed to fetch SoundCloud RSS:', err);
      throw err;
    }

    // Parse XML
    let feed: RssFeed;
    try {
      feed = xmlParser.parse(xmlText) as RssFeed;
    } catch (err) {
      console.error('Failed to parse RSS XML:', err);
      throw err;
    }

    const channel = feed?.rss?.channel;
    if (!channel) {
      console.error('Unexpected RSS structure — no channel found');
      return;
    }

    const rawItems = channel.item;
    const items: RssItem[] = Array.isArray(rawItems)
      ? rawItems
      : rawItems
      ? [rawItems]
      : [];

    if (items.length === 0) {
      console.log('No items found in RSS feed');
      return;
    }

    const batch = db.batch();
    const sermonsRef = db.collection('sermons');
    let upserted = 0;
    let skipped = 0;

    for (const item of items) {
      const audioUrl = extractAudioUrl(item);
      if (!audioUrl) {
        skipped++;
        continue;
      }

      // Deduplicate by audioUrl using a deterministic document ID
      const docId = Buffer.from(audioUrl).toString('base64url').slice(0, 64);
      const docRef = sermonsRef.doc(docId);

      const pubDate = item.pubDate ? new Date(item.pubDate) : new Date();
      const thumbnailUrl = extractThumbnail(item);

      const sermon: Omit<SermonDoc, 'id' | 'createdAt'> & {
        createdAt: FieldValue;
        updatedAt: Timestamp;
        guid: string;
      } = {
        title: String(item.title || '').trim(),
        speaker: 'David Antwi',
        description: String(item.description || '').trim(),
        audioUrl,
        thumbnailUrl,
        duration: parseDuration(item['itunes:duration'] as string | undefined),
        publishedAt: Timestamp.fromDate(pubDate),
        source: 'soundcloud',
        type: 'audio',
        playCount: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: Timestamp.fromDate(new Date()),
        guid: extractGuid(item),
      };

      // Remove undefined fields
      const cleanSermon = Object.fromEntries(
        Object.entries(sermon).filter(([, v]) => v !== undefined)
      );

      batch.set(docRef, cleanSermon, { merge: true });
      upserted++;
    }

    await batch.commit();
    console.log(`SoundCloud sync complete: ${upserted} upserted, ${skipped} skipped`);
  }
);
