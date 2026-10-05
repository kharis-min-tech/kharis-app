import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import {
  CLOCK_SKEW_MS,
  STUDIO_TEST_TOPIC,
  audienceTopic,
  buildMessage,
  claimDecision,
  isDue,
  isValidLink,
  parseAudience,
  validateNotification,
} from '../src/notifications';

const NOW = Date.parse('2026-10-05T09:00:00Z');

function doc(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    title: 'Prayer night moved',
    body: 'Friday prayer starts at 8pm this week.',
    audience: { type: 'all' },
    status: 'scheduled',
    sendAt: Timestamp.fromMillis(NOW - 1000),
    ...overrides,
  };
}

test('audience maps to the FCM topic the app subscribes to', () => {
  assert.equal(audienceTopic({ type: 'all' }), 'all');
  assert.equal(audienceTopic({ type: 'branch', branch: 'KP2 London' }), 'branch_kp2-london');
  assert.equal(audienceTopic({ type: 'test' }), STUDIO_TEST_TOPIC);
  assert.equal(STUDIO_TEST_TOPIC, 'studio_test');
});

test('audience parsing accepts the three shapes only', () => {
  assert.deepEqual(parseAudience({ type: 'all' }), { type: 'all' });
  assert.deepEqual(parseAudience({ type: 'test' }), { type: 'test' });
  assert.deepEqual(parseAudience({ type: 'branch', branch: ' North ' }), {
    type: 'branch',
    branch: 'North',
  });
  assert.equal(parseAudience({ type: 'branch', branch: '  ' }), null);
  assert.equal(parseAudience({ type: 'branch' }), null);
  assert.equal(parseAudience({ type: 'everyone' }), null);
  assert.equal(parseAudience('all'), null);
  assert.equal(parseAudience(null), null);
});

test('links: app paths and http(s) URLs only', () => {
  for (const ok of ['/m/abc', '/e/ev1', '/a/n1', '/giving', '/reading', 'https://kharis.org/x']) {
    assert.equal(isValidLink(ok), true, ok);
  }
  for (const bad of ['', '//evil.example', 'javascript:alert(1)', 'ftp://x', '/m/a b', `/${'x'.repeat(500)}`]) {
    assert.equal(isValidLink(bad), false, bad);
  }
});

test('validation trims, enforces lengths and reports the first problem', () => {
  const ok = validateNotification(doc({ title: '  Hi  ', link: '/giving' }));
  assert.deepEqual(ok, {
    ok: true,
    value: {
      title: 'Hi',
      body: 'Friday prayer starts at 8pm this week.',
      link: '/giving',
      audience: { type: 'all' },
    },
  });
  assert.equal(validateNotification(doc({ link: null })).ok, true);
  assert.equal(validateNotification(doc({ title: '' })).ok, false);
  assert.equal(validateNotification(doc({ title: 'x'.repeat(66) })).ok, false);
  assert.equal(validateNotification(doc({ title: 'x'.repeat(65) })).ok, true);
  assert.equal(validateNotification(doc({ body: 'x'.repeat(241) })).ok, false);
  assert.equal(validateNotification(doc({ body: 'x'.repeat(240) })).ok, true);
  assert.equal(validateNotification(doc({ link: 'javascript:alert(1)' })).ok, false);
  assert.equal(validateNotification(doc({ link: 42 })).ok, false);
  assert.equal(validateNotification(doc({ audience: { type: 'branch' } })).ok, false);
});

test('payload carries title, body, link and notificationId on the right topic', () => {
  const message = buildMessage('n1', {
    title: 'T',
    body: 'B',
    link: '/m/s1',
    audience: { type: 'branch', branch: 'North' },
  });
  assert.deepEqual(message, {
    topic: 'branch_north',
    notification: { title: 'T', body: 'B' },
    data: { type: 'studio', notificationId: 'n1', link: '/m/s1' },
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });
  const noLink = buildMessage('n2', { title: 'T', body: 'B', link: null, audience: { type: 'test' } });
  assert.deepEqual(noLink.data, { type: 'studio', notificationId: 'n2' });
  assert.equal(noLink.topic, 'studio_test');
});

test('due: scheduled with sendAt reached (within clock skew)', () => {
  assert.equal(isDue(doc(), NOW), true);
  assert.equal(isDue(doc({ sendAt: Timestamp.fromMillis(NOW + CLOCK_SKEW_MS) }), NOW), true);
  assert.equal(isDue(doc({ sendAt: Timestamp.fromMillis(NOW + CLOCK_SKEW_MS + 1) }), NOW), false);
  assert.equal(isDue(doc({ sendAt: Timestamp.fromMillis(NOW + 3_600_000) }), NOW), false);
  for (const status of ['draft', 'sending', 'sent', 'failed', 'cancelled']) {
    assert.equal(isDue(doc({ status }), NOW), false, status);
  }
  assert.equal(isDue(doc({ sendAt: null }), NOW), false);
  assert.equal(isDue(doc({ sendAt: '2026-10-05T08:00:00Z' }), NOW), false);
  assert.equal(isDue(undefined, NOW), false);
});

test('claim: skips what is not due, rejects invalid, sends the rest', () => {
  assert.deepEqual(claimDecision(doc({ status: 'sending' }), NOW), { action: 'skip' });
  assert.deepEqual(claimDecision(doc({ status: 'sent' }), NOW), { action: 'skip' });
  assert.deepEqual(claimDecision(undefined, NOW), { action: 'skip' });
  const rejected = claimDecision(doc({ title: '' }), NOW);
  assert.equal(rejected.action, 'reject');
  const sent = claimDecision(doc(), NOW);
  assert.equal(sent.action, 'send');
  if (sent.action === 'send') assert.deepEqual(sent.notification.audience, { type: 'all' });
});
