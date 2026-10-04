// How the fetching works:
//   1. Page through the sermons, series and playlists endpoints (they're
//      just plain JSON) until each one runs out of pages.
//   2. For tags/related messages/transcripts which aren't in those JSON
//      endpoints at all fetch each sermon's own page on the site and
//      scrape those three things out of the HTML. Skipped for any sermon
//      already scraped in a previous run (see the R2 cache further down).
//   3. Work out previous_id/next_id from the mapped list itself.
//   4. Write messages.json, playlists.json and any new transcripts to R2.

const SERMONS_URL = 'https://yetanothersermon.host/_/kc/public-api/v1/sermons';
const SERIES_URL = 'https://yetanothersermon.host/_/kc/public-api/v1/series/';
const PLAYLISTS_URL = 'https://yetanothersermon.host/_/kc/public-api/v1/playlists/';
const DETAIL_ORIGIN = new URL(SERMONS_URL).origin;

const TRANSCRIPTS_PREFIX = 'transcripts';
const CACHE_KEY = '_cache/detail-cache.json';
const REQUIRED_FIELDS = ['title', 'speaker', 'date_preached', 'audio_url'];

// Walks the count/next/previous/results pagination these endpoints use, following `next` until it comes back null.
async function fetchAllPages(startUrl) {
  let url = startUrl;
  const all = [];
  while (url) {
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`Fetch failed (${res.status}) for ${url}`);
    }
    const page = await res.json();
    all.push(...page.results);
    url = page.next;
  }
  return all;
}

// Turning the raw sermon shape from the API into the flat schema the app actually wants.

// The API sometimes hands back a url with no scheme on it at all just
// "host/path/file.mp3" instead of "https://host/path/file.mp3". Audio
// players need a real absolute URI to stream from, so patch one on if it's missing.

function toAbsoluteUrl(url) {
  if (!url) return null;
  return /^https?:\/\//i.test(url) ? url : `https://${url}`;
}

function mapSermon(raw, seriesById) {
  const rawSeriesId = raw.series?.id != null ? String(raw.series.id) : null;
  const seriesFromList = rawSeriesId ? seriesById.get(rawSeriesId) : null;

  const mapped = {
    id: String(raw.id),
    external_id: String(raw.id),
    title: raw.title ?? null,
    speaker: raw.preachers?.[0]?.name ?? null,
    date_preached: raw.date ?? null,
    series: rawSeriesId
      ? { id: rawSeriesId, name: seriesFromList?.name ?? raw.series?.name ?? null }
      : null,
    topics: [],
    keywords: [],
    scripture_refs: raw.passages ?? [],
    audio_url: toAbsoluteUrl(raw.audio_link?.download_url),
    image_url: raw.image ?? null,
    duration: raw.audio_link?.duration ?? null,
    description: raw.description ?? null,
    transcript_available: false,
    video_url: raw.video_link || null,
    tags: [],
    related_message_ids: [],
    transcript_url: null,
    previous_id: null,
    next_id: null,
  };

  return mapped;
}

// Everything below scrapes the actual sermon page instead of calling an API, because tags / related messages / transcripts just 
// don't exist anywhere in the JSON endpoints.

// Bare minimum entity list just enough to clean up apostrophes/ampersands in tag names and titles, not a real HTML decoder.

const HTML_ENTITIES = {
  '&amp;': '&',
  '&#x27;': "'",
  '&#39;': "'",
  '&quot;': '"',
  '&lt;': '<',
  '&gt;': '>',
};

function decodeEntities(str) {
  return str.replace(/&amp;|&#x27;|&#39;|&quot;|&lt;|&gt;/g, (m) => HTML_ENTITIES[m]);
}

// Grabs whatever sits inside the <div> right after a given <h3> heading
// this is how both the Tags block and the Related Messages block get pulled out.

function extractSection(html, heading) {
  const re = new RegExp(
    `<h3[^>]*>\\s*${heading}\\s*<\\/h3>\\s*<div[^>]*>([\\s\\S]*?)<\\/div>`,
    'i'
  );
  const match = html.match(re);
  return match ? match[1] : null;
}

// Most sermons don't have any tags at all

function extractTags(html) {
  const section = extractSection(html, 'Tags');
  if (!section) return [];
  const links = [...section.matchAll(/<a\b[^>]*>([^<]*)<\/a>/g)];
  return links.map((m) => decodeEntities(m[1].trim())).filter(Boolean);
}

// Pulls every sermon id out of the Related Messages links, dropping the sermon's own id in case it ever links back to itself.

function extractRelatedMessageIds(html, ownId) {
  const section = extractSection(html, 'Related Messages');
  if (!section) return [];
  const links = [...section.matchAll(/\/_\/kc\/sermons\/(\d+)\//g)];
  const ids = [...new Set(links.map((m) => m[1]))];
  return ids.filter((id) => id !== ownId);
}

// The .txt file opens with a disclaimer paragraph before the actual transcript starts, so just skip ahead to the first [m:ss] timestamp
// and take everything from there.

async function fetchTranscriptText(txtUrl) {
  const res = await fetch(txtUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  if (!res.ok) return null;
  const raw = await res.text();
  const firstTimestamp = raw.search(/\[\d+:\d+\]/);
  return firstTimestamp >= 0 ? raw.slice(firstTimestamp).trim() : raw.trim();
}

// Hits one sermon's page and pulls whatever we can off it. If the page 404s
// or the fetch just fails, don't take the whole run down over one sermon log it and hand back empty values so the rest keeps going.

async function scrapeSermonDetail(id, env) {
  const detailUrl = `${DETAIL_ORIGIN}/_/kc/sermons/${id}/`;
  try {
    const res = await fetch(detailUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!res.ok) {
      console.warn(`[scrape] detail page failed (${res.status}) for sermon ${id}`);
      return { tags: [], related_message_ids: [], transcript_available: false, transcript_url: null };
    }
    const html = await res.text();

    const tags = extractTags(html);
    const related_message_ids = extractRelatedMessageIds(html, String(id));

    // Note: this transcript id is NOT the sermon id or the audio id it's its own thing, only findable by grepping it out of the page like this.
    const txtMatch = html.match(/\/_\/kc\/transcriptions\/\d+\.txt/);
    let transcript_url = null;
    if (txtMatch) {
      const transcription = await fetchTranscriptText(`${DETAIL_ORIGIN}${txtMatch[0]}`);
      if (transcription) {
        // Written out to its own object rather than stuffed into
        // messages.json — a full transcript is tens of KB and doing that
        // for 1,400+ sermons turns a 1MB catalogue file into a 50MB+ one
        // that the app would have to re-check on every launch.
        transcript_url = `${TRANSCRIPTS_PREFIX}/${id}.txt`;
        await env.MESSAGES_BUCKET.put(transcript_url, transcription, {
          httpMetadata: { contentType: 'text/plain; charset=utf-8' },
        });
      }
    }

    return {
      tags,
      related_message_ids,
      transcript_available: Boolean(transcript_url),
      transcript_url,
    };
  } catch (err) {
    console.warn(`[scrape] failed for sermon ${id}: ${err.message}`);
    return { tags: [], related_message_ids: [], transcript_available: false, transcript_url: null };
  }
}

// Small worker-pool so we're not firing off a request per sermon all at once 

async function mapWithConcurrency(items, limit, fn) {
  const results = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const i = cursor++;
      results[i] = await fn(items[i], i);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

// previous_id / next_id aren't in the source data worked out here by grouping sermons into their series and sorting by date preached.
function computePrevNext(messages, log) {
  const bySeries = {};

  for (const msg of messages) {
    const key = msg.series?.id ?? '__no_series__';
    if (!bySeries[key]) bySeries[key] = [];
    bySeries[key].push(msg);
  }

  for (const group of Object.values(bySeries)) {
    // oldest first within each series
    group.sort((a, b) => new Date(a.date_preached) - new Date(b.date_preached));

    // if two sermons in the same series share a date, there's genuinely no
    // way to know which one actually came first log it instead of guessing
    for (let i = 1; i < group.length; i++) {
      if (group[i].date_preached === group[i - 1].date_preached) {
        log(
          `[ambiguous order] messages ${group[i - 1].id} and ${group[i].id} share date ${group[i].date_preached} in series ${group[i].series?.name}`
        );
      }
    }

    for (let i = 0; i < group.length; i++) {
      group[i].previous_id = i > 0 ? group[i - 1].id : null;
      group[i].next_id = i < group.length - 1 ? group[i + 1].id : null;
    }
  }

  return messages;
}

// Playlists shape here is a best guess (no confirmed real sample yet), covers both `sermons` and `items` in case the field name differs.

function mapPlaylist(raw) {
  return {
    id: String(raw.id),
    title: raw.title ?? raw.name ?? null,
    message_ids: (raw.sermons ?? raw.items ?? []).map((s) => String(s.id ?? s)),
  };
}

// Scraping every sermon's page is slow and there's no reason to redo it
// for sermons already scraped in a previous run results get stashed in R2 and reused.
// Only sermons missing from this cache get re-scraped!

async function loadCache(env) {
  const obj = await env.MESSAGES_BUCKET.get(CACHE_KEY);
  if (!obj) return new Map();
  try {
    const json = await obj.json();
    return new Map(Object.entries(json));
  } catch {
    return new Map();
  }
}

async function saveCache(env, cache) {
  await env.MESSAGES_BUCKET.put(CACHE_KEY, JSON.stringify(Object.fromEntries(cache), null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });
}


async function runImport(env) {
  // logs to the console (visible via `wrangler tail`) and keeps a copy so
  // the manual-trigger endpoint can hand the whole log back in its response
  const log = [];
  const push = (line) => {
    log.push(line);
    console.log(line);
  };

  push('Fetching series...');
  const rawSeries = await fetchAllPages(SERIES_URL).catch((err) => {
    push(`Series fetch failed, continuing without it: ${err.message}`);
    return [];
  });
  const seriesById = new Map(
    rawSeries.map((s) => [String(s.id), { name: s.name ?? s.title ?? null }])
  );
  push(`Fetched ${rawSeries.length} series.`);

  push('Fetching sermons...');
  const rawSermons = await fetchAllPages(SERMONS_URL);
  push(`Fetched ${rawSermons.length} sermons.`);

  push('Fetching playlists...');
  const rawPlaylists = await fetchAllPages(PLAYLISTS_URL).catch((err) => {
    push(`Playlists fetch failed, continuing without it: ${err.message}`);
    return [];
  });

  let messages = rawSermons.map((raw) => mapSermon(raw, seriesById));
  messages = computePrevNext(messages, push);

  const detailCache = await loadCache(env);
  const toScrape = messages.filter((m) => !detailCache.has(m.id));
  push(
    `Scraping detail pages for ${toScrape.length} sermon(s) (${messages.length - toScrape.length} reused from cache)...`
  );

  const concurrency = Number(env.SCRAPE_CONCURRENCY || 6);
  let scraped = 0;
  await mapWithConcurrency(toScrape, concurrency, async (msg) => {
    const detail = await scrapeSermonDetail(msg.id, env);
    detailCache.set(msg.id, detail);
    scraped++;
    if (scraped % 50 === 0) push(`  scraped ${scraped}/${toScrape.length}...`);
  });

  for (const msg of messages) {
    const detail = detailCache.get(msg.id);
    msg.tags = detail.tags;
    msg.related_message_ids = detail.related_message_ids;
    msg.transcript_available = detail.transcript_available;
    msg.transcript_url = detail.transcript_url;
  }

  await saveCache(env, detailCache);

  const playlists = rawPlaylists.map(mapPlaylist);

  await env.MESSAGES_BUCKET.put('messages.json', JSON.stringify({ messages }, null, 2), {
    httpMetadata: {
      contentType: 'application/json',
      cacheControl: 'public, max-age=300',
    },
  });
  await env.MESSAGES_BUCKET.put('playlists.json', JSON.stringify({ playlists }, null, 2), {
    httpMetadata: {
      contentType: 'application/json',
      cacheControl: 'public, max-age=300',
    },
  });

  push(`Wrote messages.json (${messages.length} records) and playlists.json (${playlists.length} records).`);

  const withMissingRequired = messages.filter((m) =>
    REQUIRED_FIELDS.some((f) => !m[f])
  );
  if (withMissingRequired.length) {
    push(`${withMissingRequired.length} sermon(s) have missing required fields.`);
  }

  return {
    messagesCount: messages.length,
    playlistsCount: playlists.length,
    scrapedThisRun: toScrape.length,
    reusedFromCache: messages.length - toScrape.length,
    log,
  };
}

export default {
  // the real cron firing, let it run in the background past the event handler
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runImport(env));
  },

  // manual trigger for testing/backfills, locked behind a secret so nobody
  // can kick off a scrape run just by finding the worker's url
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname !== '/run-import') {
      return new Response('Not found', { status: 404 });
    }
    if (!env.MANUAL_TRIGGER_SECRET || url.searchParams.get('secret') !== env.MANUAL_TRIGGER_SECRET) {
      return new Response('Unauthorized', { status: 401 });
    }
    // Handed to waitUntil first so the run isn't killed if the caller's
    // connection drops or times out before a ~1,500-sermon scrape finishes —
    // same protection scheduled() gets. Still awaited here too, so a curl
    // that stays connected gets the full JSON result back.
    const run = runImport(env);
    ctx.waitUntil(run);
    try {
      const result = await run;
      return new Response(JSON.stringify(result, null, 2), {
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (err) {
      return new Response(`Import failed: ${err.message}`, { status: 500 });
    }
  },
};
