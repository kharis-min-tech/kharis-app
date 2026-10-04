import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { NewsRecord, isPushDue, pickAnnouncements, toAnnouncement } from '../src/announcements';
import { NewsDoc } from '../src/types';

const NOW = Date.UTC(2026, 9, 3, 12, 0);
const HOUR = 3_600_000;

function news(id: string, fields: Partial<NewsDoc> & { pubOffsetH?: number }): NewsRecord {
  const { pubOffsetH = -1, ...rest } = fields;
  return {
    id,
    data: {
      title: id,
      body: '',
      publishedAt: Timestamp.fromMillis(NOW + pubOffsetH * HOUR),
      ...rest,
    },
  };
}

const ids = (list: { id: string }[]) => list.map((a) => a.id);

test('a scheduled (future publishedAt) notice is not served', () => {
  const docs = [news('live', {}), news('scheduled', { pubOffsetH: 2 })];
  assert.deepEqual(ids(pickAnnouncements(undefined, [], docs, 10, NOW)), ['live']);
});

test('a scheduled notice is served once its time arrives', () => {
  const docs = [news('scheduled', { pubOffsetH: 2 })];
  assert.deepEqual(ids(pickAnnouncements(undefined, [], docs, 10, NOW + 3 * HOUR)), ['scheduled']);
});

test('an expired notice is not served; expiry is exclusive of its instant', () => {
  const docs = [
    news('expired', { expiresAt: Timestamp.fromMillis(NOW - 1) }),
    news('expiring-now', { expiresAt: Timestamp.fromMillis(NOW) }),
    news('later', { expiresAt: Timestamp.fromMillis(NOW + HOUR) }),
  ];
  assert.deepEqual(ids(pickAnnouncements(undefined, [], docs, 10, NOW)), ['later']);
});

test('branch scope: own campus plus null, blank and absent branch, newest first', () => {
  const own = news('own', { branch: 'Chatham', pubOffsetH: -5 });
  const other = news('other', { branch: 'Reading', pubOffsetH: -1 });
  const nul = news('null', { branch: null, pubOffsetH: -2 });
  const blank = news('blank', { branch: '  ', pubOffsetH: -3 });
  const absent = news('absent', { pubOffsetH: -4 });
  const picked = pickAnnouncements('Chatham', [own], [other, nul, blank, absent, own], 10, NOW);
  assert.deepEqual(ids(picked), ['null', 'blank', 'absent', 'own']);
  assert.equal(picked.find((a) => a.id === 'blank')?.branch, null);
});

test('a campus notice is never crowded out by newer all-campus ones', () => {
  const own = news('own', { branch: 'Chatham', pubOffsetH: -10 });
  const campus = [1, 2, 3].map((n) => news(`all${n}`, { pubOffsetH: -n }));
  assert.deepEqual(ids(pickAnnouncements('Chatham', [own], campus, 2, NOW)), ['all1', 'own']);
});

test('eventId, linkUrl and ctaLabel are served; label defaults with a link', () => {
  const a = toAnnouncement(
    news('n', { eventId: 'web_1', linkUrl: 'https://kharis.org/give', ctaLabel: '' }),
  );
  assert.equal(a.eventId, 'web_1');
  assert.equal(a.linkUrl, 'https://kharis.org/give');
  assert.equal(a.ctaLabel, 'Learn more');
  const plain = toAnnouncement(news('p', { ctaLabel: 'Ignored' }));
  assert.equal(plain.linkUrl, null);
  assert.equal(plain.ctaLabel, null);
});

test('push poller: due only once published, inside the window, unexpired and unpushed', () => {
  const window = 15 * 60_000;
  const at = (minutes: number, extra: Partial<NewsDoc> & { pushedAt?: unknown } = {}) => ({
    title: 't',
    body: '',
    publishedAt: Timestamp.fromMillis(NOW + minutes * 60_000),
    ...extra,
  });
  assert.equal(isPushDue(at(-1), NOW, window), true);
  assert.equal(isPushDue(at(5), NOW, window), false, 'scheduled for later');
  assert.equal(isPushDue(at(-20), NOW, window), false, 'outside the window');
  assert.equal(isPushDue(at(-1, { pushedAt: Timestamp.fromMillis(NOW) }), NOW, window), false);
  assert.equal(
    isPushDue(at(-1, { expiresAt: Timestamp.fromMillis(NOW - 1) }), NOW, window),
    false,
  );
});
