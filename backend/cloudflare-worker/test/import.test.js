import { afterEach, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';

import worker, {
  computePrevNext,
  extractRelatedMessageIds,
  extractTags,
  fetchAllPages,
  runImport,
  scrapeReason,
  secretsMatch,
  shrinkGuard,
} from '../src/index.js';
import {
  MemoryBucket,
  PLAYLISTS_URL,
  SERIES_URL,
  SERMONS_URL,
  apiRoutes,
  detailHtml,
  detailUrl,
  installFetch,
  json,
  quietConsole,
  rawSermon,
  txtUrl,
} from './fakes.js';

const CACHE_KEY = '_cache/detail-cache.json';
const NOW = Date.parse('2026-10-18T12:00:00Z');
const DAY = 24 * 60 * 60 * 1000;
const realFetch = globalThis.fetch;

let consoleCapture;
beforeEach(() => {
  consoleCapture = quietConsole();
});
afterEach(() => {
  consoleCapture.restore();
  globalThis.fetch = realFetch;
});

function envWith(bucket, vars = {}) {
  return { MESSAGES_BUCKET: bucket, SCRAPE_CONCURRENCY: '2', ...vars };
}

function messagesById(bucket) {
  return new Map(bucket.json('messages.json').messages.map((m) => [m.id, m]));
}

function cachedEntry(extra = {}) {
  return {
    tags: ['Old'],
    related_message_ids: [],
    transcript_available: false,
    transcript_url: null,
    scraped_at: '2025-01-01T00:00:00.000Z',
    first_scraped_at: '2025-01-01T00:00:00.000Z',
    ...extra,
  };
}

describe('fetchAllPages', () => {
  test('follows next until null and passes a timeout signal', async () => {
    const calls = installFetch({
      'https://api.test/p1': json({ results: [1, 2], next: 'https://api.test/p2' }),
      'https://api.test/p2': json({ results: [3], next: null }),
    });
    assert.deepEqual(await fetchAllPages('https://api.test/p1'), [1, 2, 3]);
    assert.equal(calls.length, 2);
    for (const { init } of calls) assert.ok(init.signal instanceof AbortSignal);
  });

  test('throws when next points back at a page already fetched', async () => {
    const calls = installFetch({
      'https://api.test/p1': json({ results: [1], next: 'https://api.test/p2' }),
      'https://api.test/p2': json({ results: [2], next: 'https://api.test/p1' }),
    });
    await assert.rejects(fetchAllPages('https://api.test/p1'), /Pagination loop/);
    assert.equal(calls.length, 2);
  });

  test('throws past the page cap', async () => {
    installFetch(
      Object.fromEntries(
        Array.from({ length: 5 }, (_, i) => [
          `https://api.test/p${i}`,
          json({ results: [i], next: `https://api.test/p${i + 1}` }),
        ])
      )
    );
    await assert.rejects(fetchAllPages('https://api.test/p0', { maxPages: 3 }), /exceeded 3 pages/);
  });

  test('throws when a page has no results array', async () => {
    installFetch({ 'https://api.test/p1': json({ detail: 'oops', next: null }) });
    await assert.rejects(fetchAllPages('https://api.test/p1'), /no results array/);
  });
});

describe('HTML extraction', () => {
  test('tags survive nested markup inside the Tags block', () => {
    const html =
      '<h3 class="h">Tags</h3><div class="wrap"><div class="row"><a href="/a"><span>Faith</span></a></div>' +
      '<div class="row"><a href="/b">Grace &amp; Truth</a></div></div><div><a href="/share">Share</a></div>';
    assert.deepEqual(extractTags(html), ['Faith', 'Grace & Truth']);
  });

  test('related ids are read across nested cards and exclude the own id', () => {
    const html = detailHtml({ related: ['11', '12', '10', '11'] }) + '<a href="/_/kc/sermons/99/">footer</a>';
    assert.deepEqual(extractRelatedMessageIds(html, '10'), ['11', '12']);
  });

  test('a "Related Sermons" heading is recognised too', () => {
    const html = '<h3>Related Sermons</h3><div><a href="/_/kc/sermons/5/">x</a></div>';
    assert.deepEqual(extractRelatedMessageIds(html, '1'), ['5']);
  });
});

describe('computePrevNext', () => {
  test('missing or malformed dates sort first instead of scrambling the order', () => {
    const series = { id: 's', name: 'S' };
    const msgs = [
      { id: 'c', date_preached: '2026-03-01', series },
      { id: 'bad', date_preached: 'not a date', series },
      { id: 'a', date_preached: '2026-01-01', series },
      { id: 'none', date_preached: undefined, series },
      { id: 'b', date_preached: '2026-02-01', series },
    ];
    computePrevNext(msgs, () => {});
    const byId = Object.fromEntries(msgs.map((m) => [m.id, m]));
    assert.equal(byId.a.next_id, 'b');
    assert.equal(byId.b.previous_id, 'a');
    assert.equal(byId.b.next_id, 'c');
    assert.equal(byId.c.next_id, null);
    assert.ok(['bad', 'none'].includes(byId.a.previous_id));
  });
});

describe('scrapeReason', () => {
  const keys = new Set(['transcripts/1.txt']);
  const msg = (date) => ({ id: '1', date_preached: date });

  test('new, missing transcript object, and recent no-transcript sermons are scraped', () => {
    assert.equal(scrapeReason(msg('2020-01-01'), undefined, keys, NOW), 'new');
    assert.equal(
      scrapeReason(msg('2020-01-01'), cachedEntry({ transcript_url: 'transcripts/2.txt', transcript_available: true }), keys, NOW),
      'transcript missing'
    );
    assert.equal(scrapeReason(msg('2026-10-10'), cachedEntry(), keys, NOW), 'awaiting transcript');
  });

  test('old no-transcript sermons and present transcripts are reused', () => {
    assert.equal(scrapeReason(msg('2026-08-01'), cachedEntry(), keys, NOW), null);
    assert.equal(
      scrapeReason(msg('2026-10-10'), cachedEntry({ transcript_url: 'transcripts/1.txt', transcript_available: true }), keys, NOW),
      null
    );
  });

  test('an undated sermon falls back to its first scrape time', () => {
    const recent = cachedEntry({ first_scraped_at: new Date(NOW - 2 * DAY).toISOString() });
    assert.equal(scrapeReason(msg(null), recent, keys, NOW), 'awaiting transcript');
    assert.equal(scrapeReason(msg(null), cachedEntry(), keys, NOW), null);
  });
});

describe('shrinkGuard', () => {
  test('refuses empty and shrunken lists, allows growth and small drops', () => {
    assert.match(shrinkGuard(0, null), /empty/);
    assert.match(shrinkGuard(89, 100), /under 90%/);
    assert.equal(shrinkGuard(90, 100), null);
    assert.equal(shrinkGuard(120, 100), null);
    assert.equal(shrinkGuard(5, null), null);
  });
});

describe('runImport', () => {
  test('a failed scrape is not cached and is retried next run', async () => {
    const bucket = new MemoryBucket();
    installFetch({
      ...apiRoutes({ sermons: [rawSermon(1), rawSermon(2)] }),
      [detailUrl(1)]: new Response('boom', { status: 503 }),
      [detailUrl(2)]: new Response(detailHtml({ tags: ['Hope'] })),
    });

    const result = await runImport(envWith(bucket), { now: NOW });

    const cache = bucket.json(CACHE_KEY);
    assert.equal(cache['1'], undefined);
    assert.deepEqual(cache['2'].tags, ['Hope']);
    assert.equal(result.failedThisRun, 1);
    assert.equal(result.remainingToScrape, 1);
    // messages.json is still written, with the failed sermon's detail empty.
    const msgs = messagesById(bucket);
    assert.deepEqual(msgs.get('1').tags, []);
    assert.deepEqual(msgs.get('2').tags, ['Hope']);

    // Next run only re-scrapes the failed one.
    const calls = installFetch({
      ...apiRoutes({ sermons: [rawSermon(1), rawSermon(2)] }),
      [detailUrl(1)]: new Response(detailHtml({ tags: ['Love'] })),
    });
    await runImport(envWith(bucket), { now: NOW });
    assert.deepEqual(bucket.json(CACHE_KEY)['1'].tags, ['Love']);
    assert.ok(!calls.some((c) => c.url === detailUrl(2)));
  });

  test('a failed transcript download marks the scrape failed', async () => {
    const bucket = new MemoryBucket();
    installFetch({
      ...apiRoutes({ sermons: [rawSermon(1)] }),
      [detailUrl(1)]: new Response(detailHtml({ txtId: 77 })),
      [txtUrl(77)]: new Response('nope', { status: 500 }),
    });
    await runImport(envWith(bucket), { now: NOW });
    assert.equal(bucket.json(CACHE_KEY)['1'], undefined);
    assert.equal(bucket.objects.has('transcripts/1.txt'), false);
  });

  test('a cached transcript link whose object is missing triggers a rescrape', async () => {
    const bucket = new MemoryBucket({
      [CACHE_KEY]: JSON.stringify({
        1: cachedEntry({ transcript_available: true, transcript_url: 'transcripts/1.txt' }),
      }),
    });
    const calls = installFetch({
      ...apiRoutes({ sermons: [rawSermon(1, '2020-01-01')] }),
      [detailUrl(1)]: new Response(detailHtml({ txtId: 500 })),
      [txtUrl(500)]: new Response('Disclaimer.\n[0:00] Hello'),
    });

    await runImport(envWith(bucket), { now: NOW });

    assert.ok(calls.some((c) => c.url === detailUrl(1)));
    assert.equal(bucket.objects.get('transcripts/1.txt'), '[0:00] Hello');
    const msg = messagesById(bucket).get('1');
    assert.equal(msg.transcript_url, 'transcripts/1.txt');
    assert.equal(msg.transcript_available, true);
  });

  test('a missing transcript object is never published, even when the rescrape is deferred', async () => {
    const bucket = new MemoryBucket({
      [CACHE_KEY]: JSON.stringify({
        1: cachedEntry({ transcript_available: true, transcript_url: 'transcripts/1.txt' }),
      }),
    });
    installFetch({ ...apiRoutes({ sermons: [rawSermon(1, '2020-01-01')] }) });

    await runImport(envWith(bucket), { now: NOW, scrapeLimit: 0 });

    const msg = messagesById(bucket).get('1');
    assert.equal(msg.transcript_url, null);
    assert.equal(msg.transcript_available, false);
  });

  test('transcript keys are found across paginated bucket listings', async () => {
    const bucket = new MemoryBucket(
      {
        [CACHE_KEY]: JSON.stringify({
          1: cachedEntry({ transcript_available: true, transcript_url: 'transcripts/1.txt' }),
          2: cachedEntry({ transcript_available: true, transcript_url: 'transcripts/2.txt' }),
          3: cachedEntry({ transcript_available: true, transcript_url: 'transcripts/3.txt' }),
        }),
        'transcripts/1.txt': 'a',
        'transcripts/2.txt': 'b',
        'transcripts/3.txt': 'c',
      },
      { listPageSize: 1 }
    );
    const calls = installFetch({
      ...apiRoutes({ sermons: [rawSermon(1), rawSermon(2), rawSermon(3)] }),
    });
    const result = await runImport(envWith(bucket), { now: NOW });
    assert.equal(result.reusedFromCache, 3);
    assert.ok(!calls.some((c) => c.url.includes('/_/kc/sermons/')));
    assert.equal(messagesById(bucket).get('3').transcript_url, 'transcripts/3.txt');
  });

  test('recent sermons without a transcript are re-scraped, old ones are not', async () => {
    const bucket = new MemoryBucket({
      [CACHE_KEY]: JSON.stringify({ 1: cachedEntry(), 2: cachedEntry() }),
    });
    const calls = installFetch({
      ...apiRoutes({ sermons: [rawSermon(1, '2026-10-11'), rawSermon(2, '2026-01-01')] }),
      [detailUrl(1)]: new Response(detailHtml({ txtId: 9 })),
      [txtUrl(9)]: new Response('[0:01] Now ready'),
    });

    await runImport(envWith(bucket), { now: NOW });

    assert.ok(calls.some((c) => c.url === detailUrl(1)));
    assert.ok(!calls.some((c) => c.url === detailUrl(2)));
    const entry = bucket.json(CACHE_KEY)['1'];
    assert.equal(entry.transcript_url, 'transcripts/1.txt');
    assert.equal(entry.first_scraped_at, '2025-01-01T00:00:00.000Z');
    assert.equal(entry.scraped_at, new Date(NOW).toISOString());
  });

  test('scrapes are capped per run, newest first, and the rest wait for later runs', async () => {
    const bucket = new MemoryBucket();
    const sermons = [1, 2, 3, 4, 5].map((id) => rawSermon(id, `2026-0${id}-01`));
    const routes = { ...apiRoutes({ sermons }) };
    for (const s of sermons) routes[detailUrl(s.id)] = new Response(detailHtml());
    const calls = installFetch(routes);

    const result = await runImport(envWith(bucket, { SCRAPE_BATCH_LIMIT: '2' }), { now: NOW });

    const scraped = calls.filter((c) => c.url.includes('/_/kc/sermons/')).map((c) => c.url);
    assert.deepEqual(scraped.sort(), [detailUrl(4), detailUrl(5)]);
    assert.deepEqual(Object.keys(bucket.json(CACHE_KEY)).sort(), ['4', '5']);
    assert.equal(result.remainingToScrape, 3);
    assert.equal(bucket.json('messages.json').messages.length, 5);
  });

  test('the cache is saved every 25 scrapes, not only at the end', async () => {
    const bucket = new MemoryBucket();
    const sermons = Array.from({ length: 30 }, (_, i) => rawSermon(i + 1));
    const routes = { ...apiRoutes({ sermons }) };
    for (const s of sermons) routes[detailUrl(s.id)] = new Response(detailHtml());
    installFetch(routes);

    await runImport(envWith(bucket), { now: NOW });

    assert.equal(bucket.puts.filter((k) => k === CACHE_KEY).length, 2);
    assert.equal(Object.keys(bucket.json(CACHE_KEY)).length, 30);
  });

  test('a shrunken sermon list keeps the old messages.json', async () => {
    const previous = Array.from({ length: 10 }, (_, i) => ({ id: String(i + 1) }));
    const bucket = new MemoryBucket({ 'messages.json': JSON.stringify({ messages: previous }) });
    const sermons = [1, 2, 3, 4, 5].map((id) => rawSermon(id));
    const routes = { ...apiRoutes({ sermons, playlists: [{ id: 1, title: 'P' }] }) };
    for (const s of sermons) routes[detailUrl(s.id)] = new Response(detailHtml());
    installFetch(routes);

    const result = await runImport(envWith(bucket), { now: NOW });

    assert.equal(bucket.json('messages.json').messages.length, 10);
    assert.deepEqual(result.skipped, ['messages.json']);
    assert.deepEqual(result.written, ['playlists.json']);
    assert.ok(consoleCapture.captured.error.some((l) => l.includes('kept the existing messages.json')));
  });

  test('an empty sermon list never overwrites messages.json', async () => {
    const bucket = new MemoryBucket({ 'messages.json': JSON.stringify({ messages: [{ id: '1' }] }) });
    installFetch({ ...apiRoutes({ sermons: [] }) });
    await runImport(envWith(bucket), { now: NOW });
    assert.deepEqual(bucket.json('messages.json').messages, [{ id: '1' }]);
  });

  test('a failed playlists fetch keeps the old playlists.json', async () => {
    const oldPlaylists = JSON.stringify({ playlists: [{ id: '6', title: 'Old', message_ids: [] }] });
    const bucket = new MemoryBucket({ 'playlists.json': oldPlaylists });
    installFetch({
      ...apiRoutes({ sermons: [rawSermon(1)] }),
      [PLAYLISTS_URL]: new Response('down', { status: 502 }),
      [detailUrl(1)]: new Response(detailHtml()),
    });

    const result = await runImport(envWith(bucket), { now: NOW });

    assert.equal(bucket.objects.get('playlists.json'), oldPlaylists);
    assert.deepEqual(result.written, ['messages.json']);
    assert.equal(result.playlistsCount, null);
  });

  test('a failed series fetch keeps series names from the existing messages.json', async () => {
    const bucket = new MemoryBucket({
      'messages.json': JSON.stringify({ messages: [{ id: '1', series: { id: '7', name: 'Romans' } }] }),
    });
    installFetch({
      ...apiRoutes({ sermons: [rawSermon(1, '2026-01-01', { series: { id: 7 } })] }),
      [SERIES_URL]: new Response('down', { status: 500 }),
      [detailUrl(1)]: new Response(detailHtml()),
    });
    await runImport(envWith(bucket), { now: NOW });
    assert.deepEqual(messagesById(bucket).get('1').series, { id: '7', name: 'Romans' });
  });

  test('a failed sermons fetch aborts before anything is written', async () => {
    const bucket = new MemoryBucket();
    installFetch({ ...apiRoutes({ sermons: [] }), [SERMONS_URL]: new Response('x', { status: 500 }) });
    await assert.rejects(runImport(envWith(bucket), { now: NOW }), /Fetch failed \(500\)/);
    assert.equal(bucket.puts.length, 0);
  });

  test('records drop the always-empty topics/keywords fields', async () => {
    const bucket = new MemoryBucket();
    installFetch({ ...apiRoutes({ sermons: [rawSermon(1)] }), [detailUrl(1)]: new Response(detailHtml()) });
    await runImport(envWith(bucket), { now: NOW });
    const msg = messagesById(bucket).get('1');
    assert.equal('topics' in msg, false);
    assert.equal('keywords' in msg, false);
  });

  test('a Tags heading with nothing extracted is logged as a warning', async () => {
    const bucket = new MemoryBucket();
    installFetch({
      ...apiRoutes({ sermons: [rawSermon(1)] }),
      [detailUrl(1)]: new Response('<h3>Tags</h3><div><span>Faith</span></div>'),
    });
    await runImport(envWith(bucket), { now: NOW });
    assert.ok(consoleCapture.captured.warn.some((l) => l.includes('Tags heading but no tags')));
  });
});

describe('secretsMatch', () => {
  test('matches only the exact secret', async () => {
    assert.equal(await secretsMatch('s3cret-value', 's3cret-value'), true);
    assert.equal(await secretsMatch('s3cret-valuf', 's3cret-value'), false);
    assert.equal(await secretsMatch('s3cret', 's3cret-value'), false);
    assert.equal(await secretsMatch('', 's3cret-value'), false);
    assert.equal(await secretsMatch(null, 's3cret-value'), false);
  });

  test('an unset secret never matches', async () => {
    assert.equal(await secretsMatch('', ''), false);
    assert.equal(await secretsMatch('anything', undefined), false);
  });
});

describe('worker handlers', () => {
  const ctx = () => {
    const pending = [];
    return { pending, waitUntil: (p) => pending.push(p) };
  };
  const env = (bucket) => envWith(bucket, { MANUAL_TRIGGER_SECRET: 'top-secret' });

  test('/run-import rejects a missing, wrong or query-string secret', async () => {
    const bucket = new MemoryBucket();
    const calls = installFetch({});
    for (const req of [
      new Request('https://w.test/run-import'),
      new Request('https://w.test/run-import?secret=top-secret'),
      new Request('https://w.test/run-import', { headers: { Authorization: 'Bearer wrong' } }),
      new Request('https://w.test/run-import', { headers: { Authorization: 'top-secret' } }),
    ]) {
      const res = await worker.fetch(req, env(bucket), ctx());
      assert.equal(res.status, 401);
    }
    assert.equal(calls.length, 0);
  });

  test('/run-import with the bearer secret runs a capped batch and returns the summary', async () => {
    const bucket = new MemoryBucket();
    const sermons = [1, 2, 3].map((id) => rawSermon(id));
    const routes = { ...apiRoutes({ sermons }) };
    for (const s of sermons) routes[detailUrl(s.id)] = new Response(detailHtml());
    installFetch(routes);

    const res = await worker.fetch(
      new Request('https://w.test/run-import', { headers: { Authorization: 'Bearer top-secret' } }),
      { ...env(bucket), MANUAL_SCRAPE_LIMIT: '2' },
      ctx()
    );

    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.scrapedThisRun, 2);
    assert.equal(body.remainingToScrape, 1);
  });

  test('other paths are 404', async () => {
    const res = await worker.fetch(new Request('https://w.test/'), env(new MemoryBucket()), ctx());
    assert.equal(res.status, 404);
  });

  test('scheduled() catches and logs a failed run', async () => {
    installFetch({});
    const c = ctx();
    await worker.scheduled({ cron: '0 6 * * 1,4' }, env(new MemoryBucket()), c);
    assert.equal(c.pending.length, 1);
    await c.pending[0];
    assert.ok(consoleCapture.captured.error.some((l) => l.includes('scheduled run (0 6 * * 1,4) failed')));
  });
});
