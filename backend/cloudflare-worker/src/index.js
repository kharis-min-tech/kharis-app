// How the fetching works:
//   1. Page through the sermons, series and playlists endpoints (they're
//      just plain JSON) until each one runs out of pages.
//   2. For tags/related messages/transcripts which aren't in those JSON
//      endpoints at all fetch each sermon's own page on the site and
//      scrape those three things out of the HTML. Results are kept in an R2
//      cache (see further down) and only re-scraped when they're missing,
//      their transcript object has gone, or a recent sermon still has no
//      transcript. At most a capped batch is scraped per run.
//   3. Work out previous_id/next_id from the mapped list itself.
//   4. Write messages.json, playlists.json and any new transcripts to R2,
//      refusing to replace a catalogue file with an empty or shrunken one.

const SERMONS_URL = 'https://yetanothersermon.host/_/kc/public-api/v1/sermons';
const SERIES_URL = 'https://yetanothersermon.host/_/kc/public-api/v1/series/';
const PLAYLISTS_URL = 'https://yetanothersermon.host/_/kc/public-api/v1/playlists/';
const DETAIL_ORIGIN = new URL(SERMONS_URL).origin;

const TRANSCRIPTS_PREFIX = 'transcripts';
const CACHE_KEY = '_cache/detail-cache.json';
const MESSAGES_KEY = 'messages.json';
const PLAYLISTS_KEY = 'playlists.json';
const REQUIRED_FIELDS = ['title', 'speaker', 'date_preached', 'audio_url'];

const FETCH_TIMEOUT_MS = 15_000;
const MAX_PAGES = 200;
const DEFAULT_SCRAPE_CONCURRENCY = 6;
// Per cron run. Each scrape is up to two outbound fetches plus an R2 write,
// so this keeps a run well inside the per-invocation subrequest limit.
const DEFAULT_SCRAPE_BATCH_LIMIT = 150;
// Per /run-import call, small enough to finish while the caller waits.
const DEFAULT_MANUAL_SCRAPE_LIMIT = 25;
// The scrape cache is written every this many successful scrapes, so a run
// cut short still keeps most of its progress.
const CACHE_SAVE_EVERY = 25;
// A sermon with no transcript yet is re-scraped until it's this old (by
// date_preached, or by its first scrape when it has no date), because
// transcripts usually appear days after the sermon.
const TRANSCRIPT_RETRY_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
// A new catalogue smaller than this share of the existing one is treated as
// a broken fetch and not written.
const MIN_KEEP_RATIO = 0.9;

const HTML_HEADERS = { 'User-Agent': 'Mozilla/5.0' };

function fetchWithTimeout(url, init = {}) {
  return fetch(url, { ...init, signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
}

// Walks the count/next/previous/results pagination these endpoints use,
// following `next` until it comes back null. Throws on a repeated `next`,
// a missing `results` array or more than `maxPages` pages, so a misbehaving
// API can't loop forever or yield a silently partial list.
async function fetchAllPages(startUrl, { maxPages = MAX_PAGES } = {}) {
  let url = startUrl;
  const seen = new Set();
  const all = [];
  while (url) {
    if (seen.has(url)) {
      throw new Error(`Pagination loop: ${url} was already fetched`);
    }
    if (seen.size >= maxPages) {
      throw new Error(`Pagination exceeded ${maxPages} pages at ${url}`);
    }
    seen.add(url);
    const res = await fetchWithTimeout(url);
    if (!res.ok) {
      throw new Error(`Fetch failed (${res.status}) for ${url}`);
    }
    const page = await res.json();
    if (!Array.isArray(page?.results)) {
      throw new Error(`Page ${url} has no results array`);
    }
    all.push(...page.results);
    url = page.next || null;
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

  return {
    id: String(raw.id),
    external_id: String(raw.id),
    title: raw.title ?? null,
    speaker: raw.preachers?.[0]?.name ?? null,
    date_preached: raw.date ?? null,
    series: rawSeriesId
      ? { id: rawSeriesId, name: seriesFromList?.name ?? raw.series?.name ?? null }
      : null,
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

const TAGS_HEADING = 'Tags';
const RELATED_HEADING = 'Related (?:Messages|Sermons)';

function headingRegex(heading) {
  return new RegExp(`<h3[^>]*>\\s*${heading}\\s*<\\/h3>`, 'i');
}

function hasHeading(html, heading) {
  return headingRegex(heading).test(html);
}

// Returns the inner HTML of the first <div> after a given <h3> heading,
// matching nested <div>s so an inner card or wrapper doesn't cut it short.
// This is how both the Tags block and the Related Messages block get pulled out.
function extractSection(html, heading) {
  const headingMatch = headingRegex(heading).exec(html);
  if (!headingMatch) return null;
  const afterHeading = headingMatch.index + headingMatch[0].length;
  const open = /^\s*<div\b[^>]*>/i.exec(html.slice(afterHeading));
  if (!open) return null;

  const contentStart = afterHeading + open[0].length;
  const divTag = /<(\/?)div\b[^>]*>/gi;
  divTag.lastIndex = contentStart;
  let depth = 1;
  let tag;
  while ((tag = divTag.exec(html))) {
    depth += tag[1] ? -1 : 1;
    if (depth === 0) return html.slice(contentStart, tag.index);
  }
  return html.slice(contentStart);
}

// Most sermons don't have any tags at all

function extractTags(html) {
  const section = extractSection(html, TAGS_HEADING);
  if (!section) return [];
  const links = [...section.matchAll(/<a\b[^>]*>([\s\S]*?)<\/a>/gi)];
  return links
    .map((m) => decodeEntities(m[1].replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim()))
    .filter(Boolean);
}

// Pulls every sermon id out of the Related Messages links, dropping the sermon's own id in case it ever links back to itself.

function extractRelatedMessageIds(html, ownId) {
  const section = extractSection(html, RELATED_HEADING);
  if (!section) return [];
  const links = [...section.matchAll(/\/_\/kc\/sermons\/(\d+)\//g)];
  const ids = [...new Set(links.map((m) => m[1]))];
  return ids.filter((id) => id !== ownId);
}

// The .txt file opens with a disclaimer paragraph before the actual transcript starts, so just skip ahead to the first [m:ss] timestamp
// and take everything from there. Throws when the file can't be fetched so
// the caller can tell "no transcript" apart from "transcript fetch failed".

async function fetchTranscriptText(txtUrl) {
  const res = await fetchWithTimeout(txtUrl, { headers: HTML_HEADERS });
  if (!res.ok) throw new Error(`transcript fetch failed (${res.status}) for ${txtUrl}`);
  const raw = await res.text();
  const firstTimestamp = raw.search(/\[\d+:\d+\]/);
  return firstTimestamp >= 0 ? raw.slice(firstTimestamp).trim() : raw.trim();
}

// Hits one sermon's page and pulls whatever we can off it. Any failure (non-ok
// response, network error, timeout, failed transcript fetch) returns
// `{ failed: true }` instead of throwing, so one sermon can't take the run
// down, and the caller knows not to cache it.

async function scrapeSermonDetail(id, env, nowIso) {
  const detailUrl = `${DETAIL_ORIGIN}/_/kc/sermons/${id}/`;
  try {
    const res = await fetchWithTimeout(detailUrl, { headers: HTML_HEADERS });
    if (!res.ok) {
      console.warn(`[scrape] detail page failed (${res.status}) for sermon ${id}`);
      return { failed: true };
    }
    const html = await res.text();

    const tags = extractTags(html);
    const related_message_ids = extractRelatedMessageIds(html, String(id));
    if (!tags.length && hasHeading(html, TAGS_HEADING)) {
      console.warn(`[scrape] sermon ${id} has a Tags heading but no tags were extracted`);
    }
    if (!related_message_ids.length && hasHeading(html, RELATED_HEADING)) {
      console.warn(`[scrape] sermon ${id} has a Related heading but no ids were extracted`);
    }

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
      scraped_at: nowIso,
    };
  } catch (err) {
    console.warn(`[scrape] failed for sermon ${id}: ${err.message}`);
    return { failed: true };
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

// Unparseable or missing dates sort as the epoch instead of NaN, which would
// make the comparator inconsistent.
function dateValue(date) {
  return Date.parse(date ?? '') || 0;
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
    group.sort((a, b) => dateValue(a.date_preached) - dateValue(b.date_preached));

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

// Every key under a prefix, one paginated list call per 1,000 objects. Much
// cheaper than a head() per cached sermon.
async function listKeys(bucket, prefix) {
  const keys = new Set();
  let cursor;
  for (let page = 0; page < MAX_PAGES; page++) {
    const listed = await bucket.list({ prefix, cursor });
    for (const obj of listed.objects) keys.add(obj.key);
    if (!listed.truncated) return keys;
    cursor = listed.cursor;
  }
  throw new Error(`Listing ${prefix} exceeded ${MAX_PAGES} pages`);
}

// The array under `field` in an existing catalogue object, or null if the
// object is missing or unreadable.
async function readExistingList(env, key, field) {
  const obj = await env.MESSAGES_BUCKET.get(key);
  if (!obj) return null;
  try {
    const json = await obj.json();
    return Array.isArray(json?.[field]) ? json[field] : null;
  } catch {
    return null;
  }
}

// Refuses an empty list, or one under MIN_KEEP_RATIO of the existing count,
// so a broken upstream response can't wipe the published catalogue.
function shrinkGuard(newCount, previousCount) {
  if (newCount === 0) return 'new list is empty';
  if (previousCount != null && newCount < previousCount * MIN_KEEP_RATIO) {
    return `new list has ${newCount} records, under ${MIN_KEEP_RATIO * 100}% of the existing ${previousCount}`;
  }
  return null;
}

async function putCatalogue(env, key, body) {
  await env.MESSAGES_BUCKET.put(key, JSON.stringify(body, null, 2), {
    httpMetadata: {
      contentType: 'application/json',
      cacheControl: 'public, max-age=300',
    },
  });
}

// Why a sermon needs scraping this run, or null if its cached detail is good.
function scrapeReason(msg, cached, transcriptKeys, now) {
  if (!cached) return 'new';
  if (cached.transcript_url && !transcriptKeys.has(cached.transcript_url)) {
    return 'transcript missing';
  }
  if (!cached.transcript_available) {
    const since = dateValue(msg.date_preached) || dateValue(cached.first_scraped_at);
    if (since && now - since < TRANSCRIPT_RETRY_WINDOW_MS) return 'awaiting transcript';
  }
  return null;
}

const REASON_PRIORITY = { new: 0, 'transcript missing': 1, 'awaiting transcript': 2 };

function positiveInt(value, fallback) {
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}

async function runImport(env, { scrapeLimit, now = Date.now() } = {}) {
  // logs to the console (visible via `wrangler tail`) and keeps a copy so
  // the manual-trigger endpoint can hand the whole log back in its response
  const log = [];
  const push = (line) => {
    log.push(line);
    console.log(line);
  };
  const nowIso = new Date(now).toISOString();
  const limit = scrapeLimit ?? positiveInt(env.SCRAPE_BATCH_LIMIT, DEFAULT_SCRAPE_BATCH_LIMIT);

  push('Fetching series...');
  let seriesFetchFailed = false;
  const rawSeries = await fetchAllPages(SERIES_URL).catch((err) => {
    push(`Series fetch failed, falling back to the existing messages.json names: ${err.message}`);
    seriesFetchFailed = true;
    return [];
  });
  push(`Fetched ${rawSeries.length} series.`);

  push('Fetching sermons...');
  const rawSermons = await fetchAllPages(SERMONS_URL);
  push(`Fetched ${rawSermons.length} sermons.`);

  push('Fetching playlists...');
  const rawPlaylists = await fetchAllPages(PLAYLISTS_URL).catch((err) => {
    push(`Playlists fetch failed, keeping the existing playlists.json: ${err.message}`);
    return null;
  });

  const previousMessages = await readExistingList(env, MESSAGES_KEY, 'messages');
  const seriesById = new Map(
    rawSeries.map((s) => [String(s.id), { name: s.name ?? s.title ?? null }])
  );
  if (seriesFetchFailed && previousMessages) {
    for (const m of previousMessages) {
      if (m?.series?.id != null && m.series.name) {
        seriesById.set(String(m.series.id), { name: m.series.name });
      }
    }
  }

  let messages = rawSermons.map((raw) => mapSermon(raw, seriesById));
  messages = computePrevNext(messages, push);

  const detailCache = await loadCache(env);
  const transcriptKeys = await listKeys(env.MESSAGES_BUCKET, `${TRANSCRIPTS_PREFIX}/`);

  const candidates = [];
  for (const msg of messages) {
    const reason = scrapeReason(msg, detailCache.get(msg.id), transcriptKeys, now);
    if (reason) candidates.push({ msg, reason });
  }
  // New sermons first, then broken transcript links, then recent sermons
  // still waiting on a transcript; newest first within each group.
  candidates.sort(
    (a, b) =>
      REASON_PRIORITY[a.reason] - REASON_PRIORITY[b.reason] ||
      dateValue(b.msg.date_preached) - dateValue(a.msg.date_preached)
  );
  const toScrape = candidates.slice(0, limit);
  const counts = {};
  for (const c of candidates) counts[c.reason] = (counts[c.reason] ?? 0) + 1;
  push(
    `Scraping ${toScrape.length} of ${candidates.length} sermon(s) needing it ` +
      `(${JSON.stringify(counts)}; limit ${limit}); ${messages.length - candidates.length} reused from cache...`
  );

  const concurrency = positiveInt(env.SCRAPE_CONCURRENCY, DEFAULT_SCRAPE_CONCURRENCY);
  let attempted = 0;
  let succeeded = 0;
  let failed = 0;
  let unsaved = 0;
  // Serialises cache writes so concurrent workers never interleave puts.
  let saving = Promise.resolve();
  const save = () => {
    unsaved = 0;
    saving = saving.then(() => saveCache(env, detailCache));
    return saving;
  };

  await mapWithConcurrency(toScrape, concurrency, async ({ msg }) => {
    const detail = await scrapeSermonDetail(msg.id, env, nowIso);
    attempted++;
    if (detail.failed) {
      failed++;
    } else {
      const previous = detailCache.get(msg.id);
      detail.first_scraped_at = previous?.first_scraped_at ?? previous?.scraped_at ?? nowIso;
      detailCache.set(msg.id, detail);
      if (detail.transcript_url) transcriptKeys.add(detail.transcript_url);
      succeeded++;
      if (++unsaved >= CACHE_SAVE_EVERY) await save();
    }
    if (attempted % 50 === 0) push(`  scraped ${attempted}/${toScrape.length}...`);
  });
  await save();
  push(`Scraped ${succeeded} sermon(s), ${failed} failed (not cached, retried next run).`);

  // Every sermon gets whatever detail is available. A cached transcript link
  // whose object isn't in the bucket is dropped rather than published as a 404.
  for (const msg of messages) {
    const detail = detailCache.get(msg.id);
    if (!detail) continue;
    const hasTranscript = Boolean(detail.transcript_url) && transcriptKeys.has(detail.transcript_url);
    msg.tags = detail.tags ?? [];
    msg.related_message_ids = detail.related_message_ids ?? [];
    msg.transcript_available = hasTranscript;
    msg.transcript_url = hasTranscript ? detail.transcript_url : null;
  }

  const written = [];
  const skipped = [];

  const messagesProblem = shrinkGuard(messages.length, previousMessages?.length);
  if (messagesProblem) {
    skipped.push(MESSAGES_KEY);
    console.error(`[import] kept the existing ${MESSAGES_KEY}: ${messagesProblem}`);
    log.push(`Kept the existing ${MESSAGES_KEY}: ${messagesProblem}`);
  } else {
    await putCatalogue(env, MESSAGES_KEY, { messages });
    written.push(MESSAGES_KEY);
  }

  let playlists = null;
  if (rawPlaylists) {
    playlists = rawPlaylists.map(mapPlaylist);
    const previousPlaylists = await readExistingList(env, PLAYLISTS_KEY, 'playlists');
    const playlistsProblem = shrinkGuard(playlists.length, previousPlaylists?.length);
    if (playlistsProblem) {
      skipped.push(PLAYLISTS_KEY);
      console.error(`[import] kept the existing ${PLAYLISTS_KEY}: ${playlistsProblem}`);
      log.push(`Kept the existing ${PLAYLISTS_KEY}: ${playlistsProblem}`);
    } else {
      await putCatalogue(env, PLAYLISTS_KEY, { playlists });
      written.push(PLAYLISTS_KEY);
    }
  } else {
    skipped.push(PLAYLISTS_KEY);
  }

  push(
    `Wrote ${written.join(', ') || 'nothing'} (${messages.length} messages, ${playlists?.length ?? 'no'} playlists)` +
      (skipped.length ? `; skipped ${skipped.join(', ')}.` : '.')
  );

  const withMissingRequired = messages.filter((m) => REQUIRED_FIELDS.some((f) => !m[f]));
  if (withMissingRequired.length) {
    push(`${withMissingRequired.length} sermon(s) have missing required fields.`);
  }

  return {
    messagesCount: messages.length,
    playlistsCount: playlists?.length ?? null,
    scrapedThisRun: succeeded,
    failedThisRun: failed,
    remainingToScrape: candidates.length - succeeded,
    reusedFromCache: messages.length - candidates.length,
    written,
    skipped,
    log,
  };
}

// Constant-time string comparison: both sides are hashed to fixed-length
// digests first, so neither the length nor the first differing byte leaks
// through timing.
async function secretsMatch(provided, expected) {
  if (typeof provided !== 'string' || typeof expected !== 'string' || !expected) return false;
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(provided)),
    crypto.subtle.digest('SHA-256', enc.encode(expected)),
  ]);
  const x = new Uint8Array(a);
  const y = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

function bearerToken(request) {
  const match = /^Bearer\s+(.+)$/i.exec(request.headers.get('Authorization') ?? '');
  return match ? match[1].trim() : null;
}

export {
  computePrevNext,
  extractRelatedMessageIds,
  extractSection,
  extractTags,
  fetchAllPages,
  runImport,
  scrapeReason,
  scrapeSermonDetail,
  secretsMatch,
  shrinkGuard,
};

export default {
  // The real cron firing. Failures are logged as errors so they show up in
  // Workers logs/alerts instead of vanishing as an unhandled rejection.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(
      runImport(env).catch((err) => {
        console.error(`[import] scheduled run (${event.cron}) failed: ${err.stack || err.message}`);
      })
    );
  },

  // Manual trigger for testing/backfills, locked behind a secret sent as
  // `Authorization: Bearer <secret>`. Each call scrapes a small capped batch
  // (MANUAL_SCRAPE_LIMIT) so it finishes while the caller waits; call it
  // again until `remainingToScrape` is 0. The cache is saved as it goes, so
  // a dropped connection loses at most the last few scrapes.
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname !== '/run-import') {
      return new Response('Not found', { status: 404 });
    }
    if (!(await secretsMatch(bearerToken(request), env.MANUAL_TRIGGER_SECRET))) {
      return new Response('Unauthorized', { status: 401 });
    }
    const run = runImport(env, {
      scrapeLimit: positiveInt(env.MANUAL_SCRAPE_LIMIT, DEFAULT_MANUAL_SCRAPE_LIMIT),
    });
    ctx.waitUntil(run.catch(() => {}));
    try {
      const result = await run;
      return new Response(JSON.stringify(result, null, 2), {
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (err) {
      console.error(`[import] manual run failed: ${err.stack || err.message}`);
      return new Response(`Import failed: ${err.message}`, { status: 500 });
    }
  },
};
