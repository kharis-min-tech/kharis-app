import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { decodeHtmlEntities, htmlToText } from '../src/html-text';
import { TtlCache } from '../src/response-cache';
import { isBirthdayCelebrant } from '../src/birthdays';
import { isStaleWebEvent } from '../src/sync-website-events';

// ── html-text ────────────────────────────────────────────────────────────────

test('numeric entities beyond U+10FFFF are left as-is instead of throwing', () => {
  assert.equal(decodeHtmlEntities('a &#99999999; b'), 'a &#99999999; b');
  assert.equal(decodeHtmlEntities('&#x110000;'), '&#x110000;');
  assert.equal(decodeHtmlEntities('&#xFFFFFFFFFFFFFFFFFFFF;'), '&#xFFFFFFFFFFFFFFFFFFFF;');
  assert.equal(
    decodeHtmlEntities(`&#${'9'.repeat(400)};`),
    `&#${'9'.repeat(400)};`,
    'a number too large for a double (Infinity) is left as-is',
  );
  assert.equal(htmlToText('<p>Hi &#99999999;</p>'), 'Hi &#99999999;');
});

test('valid numeric entities still decode, up to U+10FFFF', () => {
  assert.equal(decodeHtmlEntities('&#39;&#8211;&#x1F600;'), "'–😀");
  assert.equal(decodeHtmlEntities('&#x10FFFF;'), String.fromCodePoint(0x10ffff));
});

// ── TtlCache ─────────────────────────────────────────────────────────────────

test('TTL cache serves a hit until it expires, then reloads', async () => {
  let now = 0;
  const cache = new TtlCache<number>(10, () => now);
  let loads = 0;
  const load = async () => ++loads;
  assert.equal(await cache.getOrLoad('k', 1000, load), 1);
  now = 999;
  assert.equal(await cache.getOrLoad('k', 1000, load), 1);
  now = 1000;
  assert.equal(await cache.getOrLoad('k', 1000, load), 2);
  assert.equal(loads, 2);
});

test('TTL cache evicts the oldest entry at capacity', () => {
  const cache = new TtlCache<string>(2, () => 0);
  cache.set('a', 'A', 1000);
  cache.set('b', 'B', 1000);
  cache.set('c', 'C', 1000);
  assert.equal(cache.get('a'), undefined);
  assert.equal(cache.get('b'), 'B');
  assert.equal(cache.get('c'), 'C');
});

test('TTL cache does not cache a failed load', async () => {
  const cache = new TtlCache<string>(2, () => 0);
  await assert.rejects(
    cache.getOrLoad('k', 1000, async () => {
      throw new Error('boom');
    }),
  );
  assert.equal(await cache.getOrLoad('k', 1000, async () => 'ok'), 'ok');
});

// ── birthdays ────────────────────────────────────────────────────────────────

test('birthday celebrant needs a matching string dob and a device token', () => {
  assert.equal(isBirthdayCelebrant({ dob: '1990-10-18', fcmToken: 't' }, '10-18'), true);
  assert.equal(isBirthdayCelebrant({ dob: '1990-10-19', fcmToken: 't' }, '10-18'), false);
  assert.equal(isBirthdayCelebrant({ dob: '1990-10-18' }, '10-18'), false);
  assert.equal(isBirthdayCelebrant({ dob: '1990-10-18', fcmToken: '' }, '10-18'), false);
  assert.equal(isBirthdayCelebrant({ dob: 19901018, fcmToken: 't' }, '10-18'), false);
});

// ── syncWebsiteEvents stale sweep ────────────────────────────────────────────

const NOW = Date.UTC(2026, 9, 18, 12);
const DAY = 86_400_000;
const upcoming = (extra: Record<string, unknown> = {}) => ({
  source: 'website',
  sourceId: 42,
  startTime: Timestamp.fromMillis(NOW + 3 * DAY),
  ...extra,
});

test('an unseen upcoming import is stale and deleted', () => {
  assert.equal(isStaleWebEvent('web_42', upcoming(), new Set(), new Set(), NOW), true);
});

test('docs seen this run are kept', () => {
  assert.equal(isStaleWebEvent('web_42', upcoming(), new Set(['web_42']), new Set(), NOW), false);
});

test('every occurrence of a skipped post survives, admin overrides included', () => {
  const doc = upcoming({ branch: 'North', imageUrl: 'x', isFeatured: true });
  assert.equal(isStaleWebEvent('web_42_3_north', doc, new Set(), new Set([42]), NOW), false);
  // A different, unskipped post is still swept.
  assert.equal(
    isStaleWebEvent('web_7', upcoming({ sourceId: 7 }), new Set(), new Set([42]), NOW),
    true,
  );
});

test('a hidden tombstone is never swept', () => {
  assert.equal(
    isStaleWebEvent('web_42', upcoming({ hidden: true }), new Set(), new Set(), NOW),
    false,
  );
});

test('past events and events beyond the import window are kept', () => {
  assert.equal(
    isStaleWebEvent(
      'web_42',
      upcoming({ startTime: Timestamp.fromMillis(NOW - DAY) }),
      new Set(),
      new Set(),
      NOW,
    ),
    false,
  );
  assert.equal(
    isStaleWebEvent(
      'web_42',
      upcoming({ startTime: Timestamp.fromMillis(NOW + 120 * DAY) }),
      new Set(),
      new Set(),
      NOW,
    ),
    false,
  );
});
