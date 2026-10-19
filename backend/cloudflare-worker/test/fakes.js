// In-memory stand-ins for the R2 binding and the outbound fetch, just enough
// of each API for src/index.js.

export class MemoryBucket {
  constructor(entries = {}, { listPageSize = 1000 } = {}) {
    this.objects = new Map(Object.entries(entries));
    this.listPageSize = listPageSize;
    this.puts = [];
  }

  async put(key, value) {
    this.objects.set(key, String(value));
    this.puts.push(key);
  }

  async get(key) {
    if (!this.objects.has(key)) return null;
    const body = this.objects.get(key);
    return { text: async () => body, json: async () => JSON.parse(body) };
  }

  async list({ prefix = '', cursor } = {}) {
    const keys = [...this.objects.keys()].filter((k) => k.startsWith(prefix)).sort();
    const start = cursor ? Number(cursor) : 0;
    const page = keys.slice(start, start + this.listPageSize);
    const end = start + page.length;
    return {
      objects: page.map((key) => ({ key })),
      truncated: end < keys.length,
      cursor: end < keys.length ? String(end) : undefined,
    };
  }

  json(key) {
    return JSON.parse(this.objects.get(key));
  }
}

export const API = 'https://yetanothersermon.host/_/kc/public-api/v1';
export const SERMONS_URL = `${API}/sermons`;
export const SERIES_URL = `${API}/series/`;
export const PLAYLISTS_URL = `${API}/playlists/`;
export const ORIGIN = 'https://yetanothersermon.host';

export function rawSermon(id, date = '2026-01-01', extra = {}) {
  return {
    id,
    title: `Sermon ${id}`,
    date,
    preachers: [{ name: 'Speaker' }],
    audio_link: { download_url: `host/${id}.mp3`, duration: 60 },
    series: null,
    ...extra,
  };
}

export function detailHtml({ tags = [], related = [], txtId = null } = {}) {
  return [
    '<html><body>',
    tags.length
      ? `<h3>Tags</h3><div class="tags">${tags.map((t) => `<a href="/t/">${t}</a>`).join('')}</div>`
      : '',
    related.length
      ? `<h3>Related Messages</h3><div>${related
          .map((id) => `<div class="card"><a href="/_/kc/sermons/${id}/">x</a></div>`)
          .join('')}</div>`
      : '',
    txtId ? `<a href="/_/kc/transcriptions/${txtId}.txt">Transcript</a>` : '',
    '</body></html>',
  ].join('');
}

export function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Installs a global fetch routed by exact URL. Unrouted URLs return 404.
// Returns the list of { url, init } calls made.
export function installFetch(routes) {
  const calls = [];
  globalThis.fetch = async (url, init = {}) => {
    calls.push({ url: String(url), init });
    const route = routes[String(url)];
    if (!route) return new Response('not found', { status: 404 });
    return typeof route === 'function' ? route(init) : route.clone();
  };
  return calls;
}

// Standard API routes: one page each for series, sermons and playlists.
export function apiRoutes({ sermons, series = [], playlists = [] }) {
  return {
    [SERIES_URL]: json({ results: series, next: null }),
    [SERMONS_URL]: json({ results: sermons, next: null }),
    [PLAYLISTS_URL]: json({ results: playlists, next: null }),
  };
}

export function detailUrl(id) {
  return `${ORIGIN}/_/kc/sermons/${id}/`;
}

export function txtUrl(txtId) {
  return `${ORIGIN}/_/kc/transcriptions/${txtId}.txt`;
}

export function quietConsole() {
  const original = { log: console.log, warn: console.warn, error: console.error };
  const captured = { log: [], warn: [], error: [] };
  for (const level of Object.keys(original)) {
    console[level] = (...args) => captured[level].push(args.join(' '));
  }
  return { captured, restore: () => Object.assign(console, original) };
}
