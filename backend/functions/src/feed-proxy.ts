import { onRequest } from 'firebase-functions/v2/https';

const SC_FEED = 'https://feeds.soundcloud.com/users/soundcloud:users:58625221/sounds.rss';
const YT_CHANNEL = 'UC4l8WmdF9ivMDQHHVOdYKqQ';
const YT_FEED = `https://www.youtube.com/feeds/videos.xml?channel_id=${YT_CHANNEL}`;

/**
 * CORS-safe proxy for SoundCloud and YouTube RSS feeds.
 *
 * GET /feed-proxy?source=soundcloud  -> SoundCloud RSS XML
 * GET /feed-proxy?source=youtube     -> YouTube Atom XML
 *
 * Caches upstream responses for 5 minutes (CDN) / 1 minute (browser)
 * so the church's SoundCloud/YouTube never sees more than ~12 req/hour
 * regardless of how many app users hit it.
 */
export const feedProxy = onRequest(
  { cors: true, region: 'europe-west1', memory: '256MiB' },
  async (req, res) => {
    const source = (req.query.source as string || '').toLowerCase();
    const url = source === 'youtube' ? YT_FEED : SC_FEED;

    try {
      const upstream = await fetch(url, {
        headers: { 'User-Agent': 'KharisApp/2.0 (Firebase Functions)' },
      });
      if (!upstream.ok) {
        res.status(upstream.status).send(await upstream.text());
        return;
      }
      const xml = await upstream.text();
      res.set('Cache-Control', 'public, max-age=60, s-maxage=300');
      res.set('Content-Type', upstream.headers.get('content-type') || 'application/xml');
      res.send(xml);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      res.status(502).send(`Upstream fetch failed: ${message}`);
    }
  },
);
