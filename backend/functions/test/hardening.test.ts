import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { AnnouncementPushSteps, pushAnnouncementOnce } from '../src/announcements';
import { decodeHtmlEntities, htmlToText } from '../src/html-text';
import { TtlCache } from '../src/response-cache';
import { isBirthdayCelebrant } from '../src/birthdays';
import { isStaleWebEvent } from '../src/sync-website-events';

// ── pushAnnouncementOnce ─────────────────────────────────────────────────────

function steps(overrides: Partial<AnnouncementPushSteps> = {}) {
  const calls: string[] = [];
  const base: AnnouncementPushSteps = {
    claim: async () => {
      calls.push('claim');
      return true;
    },
    send: async () => {
      calls.push('send');
      return 'msg-1';
    },
    markPushed: async (id) => {
      calls.push(`markPushed:${id}`);
    },
    release: async () => {
      calls.push('release');
    },
    recordError: async () => {
      calls.push('recordError');
    },
  };
  const wrapped: AnnouncementPushSteps = { ...base };
  for (const [key, fn] of Object.entries(overrides)) {
    (wrapped as unknown as Record<string, unknown>)[key] = async (...args: unknown[]) => {
      calls.push(key);
      return (fn as (...a: unknown[]) => unknown)(...args);
    };
  }
  return { steps: wrapped, calls };
}

test('announcement push claims before sending, then records pushedAt', async () => {
  const { steps: s, calls } = steps();
  assert.equal(await pushAnnouncementOnce(s), 'sent');
  assert.deepEqual(calls, ['claim', 'send', 'markPushed:msg-1']);
});

test('an already-claimed announcement is never sent again', async () => {
  const { steps: s, calls } = steps({ claim: async () => false });
  assert.equal(await pushAnnouncementOnce(s), 'already-claimed');
  assert.deepEqual(calls, ['claim']);
});

test('a failed send releases the claim and records the error', async () => {
  const { steps: s, calls } = steps({
    send: async () => {
      throw new Error('fcm down');
    },
  });
  assert.equal(await pushAnnouncementOnce(s), 'failed');
  assert.deepEqual(calls, ['claim', 'send', 'release', 'recordError']);
});

test('a failed pushedAt write after a good send keeps the claim (no resend)', async () => {
  const claims = new Set<string>();
  let sends = 0;
  const run = () =>
    pushAnnouncementOnce({
      claim: async () => {
        if (claims.has('news_a')) return false;
        claims.add('news_a');
        return true;
      },
      send: async () => {
        sends++;
        return 'm';
      },
      markPushed: async () => {
        throw new Error('firestore write failed');
      },
      release: async () => {
        claims.delete('news_a');
      },
      recordError: async () => undefined,
    });
  assert.equal(await run(), 'sent');
  // Next scheduler run: the doc still has no pushedAt, but the claim holds.
  assert.equal(await run(), 'already-claimed');
  assert.equal(sends, 1);
  assert.ok(claims.has('news_a'));
});

test('overlapping runs send once', async () => {
  const claims = new Set<string>();
  let sends = 0;
  const run = () =>
    pushAnnouncementOnce({
      claim: async () => {
        if (claims.has('k')) return false;
        claims.add('k');
        return true;
      },
      send: async () => {
        sends++;
        return 'm';
      },
      markPushed: async () => undefined,
      release: async () => undefined,
      recordError: async () => undefined,
    });
  const outcomes = await Promise.all([run(), run()]);
  assert.deepEqual(outcomes.sort(), ['already-claimed', 'sent']);
  assert.equal(sends, 1);
});

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
