import { onRequest } from 'firebase-functions/v2/https';
import type { Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';

/**
 * CORS proxy for the public sermon API (finding D1).
 *
 * yetanothersermon.host sends no CORS headers, so the hosted web app cannot
 * call it and silently fell back to a stale bundled archive. Native apps call
 * the API directly; web calls go through here:
 *
 *   GET /sermonApiProxy/sermons/?page=2      -> UPSTREAM/sermons/?page=2
 *   GET /sermonApiProxy/series/              -> UPSTREAM/series/
 *   GET /sermonApiProxy/playlists/<id>/      -> UPSTREAM/playlists/<id>/
 *
 * Only those three resources are forwarded, GET only, query string verbatim.
 * Absolute upstream links in the body (`next` / `previous`) are rewritten to
 * this proxy so a web client that follows `next` stays on it.
 */

export const SERMON_API_UPSTREAM = 'https://yetanothersermon.host/_/kc/public-api/v1/';

/** The upstream rejects non-browser user agents. */
export const BROWSER_USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

export const SERMON_PROXY_CACHE_CONTROL = 'public, max-age=300';

const REGION = 'us-central1';

/** `sermons/`, `series/`, `playlists/` and sub-resources such as `sermons/123/`. */
const ALLOWED_PATH = /^\/(sermons|series|playlists)\/(?:[A-Za-z0-9_-]+\/)*$/;

/** Web origins allowed to call the proxy: the app and the Content Studio. */
export const SERMON_PROXY_ORIGINS: Array<string | RegExp> = [
  'https://kharis-app-47c49.web.app',
  'https://kharis-app-47c49.firebaseapp.com',
  'https://kharis-app-admin.web.app',
  'https://kharis-app-admin.firebaseapp.com',
  /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
];

/**
 * Upstream URL for a proxied request, or null when [path] is not one of the
 * forwarded resources. [rawQuery] is the query string without `?`.
 */
export function upstreamUrl(path: string, rawQuery: string): string | null {
  if (!ALLOWED_PATH.test(path)) return null;
  return `${SERMON_API_UPSTREAM}${path.slice(1)}${rawQuery ? `?${rawQuery}` : ''}`;
}

/** Public base URL of this function, for rewriting upstream links. */
export function proxyBase(host: string | undefined): string {
  const project = process.env.GCLOUD_PROJECT ?? 'kharis-app-47c49';
  if (process.env.FUNCTIONS_EMULATOR === 'true' && host) {
    return `http://${host}/${project}/${REGION}/sermonApiProxy/`;
  }
  return `https://${REGION}-${project}.cloudfunctions.net/sermonApiProxy/`;
}

type Fetch = typeof fetch;

/** The request handler, with `fetch` injectable for tests. */
export async function handleSermonProxy(
  req: Pick<Request, 'method' | 'path' | 'url'> & { get(name: string): string | undefined },
  res: Response,
  fetchImpl: Fetch = fetch,
): Promise<void> {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }
  const query = req.url.includes('?') ? req.url.slice(req.url.indexOf('?') + 1) : '';
  const target = upstreamUrl(req.path, query);
  if (!target) {
    res.status(404).json({ error: 'Only sermons/, series/ and playlists/ are proxied' });
    return;
  }

  try {
    const upstream = await fetchImpl(target, {
      headers: { 'User-Agent': BROWSER_USER_AGENT, Accept: 'application/json' },
    });
    const body = (await upstream.text())
      .split(SERMON_API_UPSTREAM)
      .join(proxyBase(req.get('host')));
    res.set('Content-Type', upstream.headers.get('content-type') ?? 'application/json');
    // Only a good page is shared through the CDN; an upstream error must not
    // be pinned for five minutes.
    res.set('Cache-Control', upstream.ok ? SERMON_PROXY_CACHE_CONTROL : 'no-store');
    res.status(upstream.status).send(body);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    res.set('Cache-Control', 'no-store');
    res.status(502).json({ error: `Upstream fetch failed: ${message}` });
  }
}

export const sermonApiProxy = onRequest(
  {
    cors: SERMON_PROXY_ORIGINS,
    region: REGION,
    memory: '256MiB',
    timeoutSeconds: 30,
  },
  (req, res) => handleSermonProxy(req, res),
);
