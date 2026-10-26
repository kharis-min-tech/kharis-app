import { test } from 'node:test';
import assert from 'node:assert/strict';
import { StudioRow } from '../src/content-studio';
import { PushState } from '../src/push-state';
import {
  PushMessage,
  StudioPushDeps,
  runAnnouncementPush,
  runBranchUpdatePush,
  runEventPush,
  runServiceReminderPush,
} from '../src/studio-pushes';

const MIN = 60_000;
const DAY = 86_400_000;
// Mon 26 Oct 2026, 12:00 London (GMT, the day after the clocks go back).
const NOW = Date.UTC(2026, 9, 26, 12, 0);
const at = (ms: number) => new Date(ms).toISOString();

/**
 * A Studio (Supabase tables served from [tables], each table's rows whatever
 * the query: the code under test must do its own filtering), FCM and push
 * state, all in memory.
 */
function harness(tables: Record<string, StudioRow[]> = {}) {
  const urls: URL[] = [];
  const sent: PushMessage[] = [];
  const claims = new Set<string>();
  const saved = new Map<string, unknown>();
  let failSends = false;
  const state: PushState = {
    claim: async (key) => {
      if (claims.has(key)) return false;
      claims.add(key);
      return true;
    },
    release: async (key) => {
      claims.delete(key);
    },
    recordSent: async () => undefined,
    get: async <T>(key: string) => (saved.has(key) ? (structuredClone(saved.get(key)) as T) : null),
    save: async (key, value) => {
      saved.set(key, structuredClone(value));
    },
  };
  const deps: StudioPushDeps = {
    fetchImpl: (async (input: string) => {
      const url = new URL(input);
      urls.push(url);
      const table = url.pathname.split('/').pop() ?? '';
      return new Response(JSON.stringify(tables[table] ?? []), { status: 200 });
    }) as unknown as typeof fetch,
    state,
    send: async (message) => {
      if (failSends) throw new Error('messaging/unavailable');
      sent.push(message);
      return `msg-${sent.length}`;
    },
  };
  return {
    deps,
    tables,
    urls,
    sent,
    claims,
    saved,
    failSends: (fail: boolean) => {
      failSends = fail;
    },
  };
}

const condition = (m: PushMessage) => ('condition' in m.audience ? m.audience.condition : m.audience.topic);

// ── Announcements ───────────────────────────────────────────────────────────

function news(id: string, fields: StudioRow = {}): StudioRow {
  return {
    id,
    title: `Notice ${id}`,
    body: 'Body',
    workspace: 'app',
    branch_name: 'Chatham',
    published_at: at(NOW - 2 * MIN),
    expires_at: null,
    ...fields,
  };
}

test('announcement: published within 15 minutes, pushed once to its branch minus muted devices', async () => {
  const h = harness({ news: [news('n1', { body: 'x'.repeat(200), event_id: 'e9' })] });
  assert.deepEqual(await runAnnouncementPush(h.deps, NOW), { sent: 1, failed: 0 });
  assert.deepEqual(await runAnnouncementPush(h.deps, NOW + MIN), { sent: 0, failed: 0 });
  assert.equal(h.sent.length, 1);
  assert.deepEqual(h.sent[0], {
    audience: { condition: "'branch_chatham' in topics && !('mute_announcements' in topics)" },
    title: 'Notice n1',
    body: `${'x'.repeat(137)}...`,
    data: { type: 'announcement', newsId: 'n1', branch: 'Chatham', eventId: 'e9' },
  });

  const q = h.urls[0];
  assert.equal(q.pathname, '/rest/v1/news');
  assert.equal(q.searchParams.get('workspace'), 'in.(app,general)');
  assert.deepEqual(q.searchParams.getAll('published_at'), [
    `gt.${at(NOW - 15 * MIN)}`,
    `lte.${at(NOW)}`,
  ]);
});

test('announcement for every branch goes to `all` minus muted devices', async () => {
  const h = harness({ news: [news('n2', { branch_name: null, workspace: 'general', body: '' })] });
  await runAnnouncementPush(h.deps, NOW);
  assert.equal(condition(h.sent[0]), "'all' in topics && !('mute_announcements' in topics)");
  assert.equal(h.sent[0].body, 'New announcement');
  assert.equal(h.sent[0].data.branch, '');
});

test('expired, website-workspace, scheduled, stale and draft announcements are not pushed', async () => {
  const h = harness({
    news: [
      news('expired', { expires_at: at(NOW - MIN) }),
      news('website', { workspace: 'kharis' }),
      news('scheduled', { published_at: at(NOW + 5 * MIN) }),
      news('stale', { published_at: at(NOW - 20 * MIN) }),
      news('draft', { status: 'draft' }),
      news('untitled', { title: '  ' }),
    ],
  });
  assert.deepEqual(await runAnnouncementPush(h.deps, NOW), { sent: 0, failed: 0 });
  assert.equal(h.sent.length, 0);
});

test('a failed announcement send is retried next minute, then sent once', async () => {
  const h = harness({ news: [news('n3')] });
  h.failSends(true);
  assert.deepEqual(await runAnnouncementPush(h.deps, NOW), { sent: 0, failed: 1 });
  h.failSends(false);
  assert.deepEqual(await runAnnouncementPush(h.deps, NOW + MIN), { sent: 1, failed: 0 });
  assert.deepEqual(await runAnnouncementPush(h.deps, NOW + 2 * MIN), { sent: 0, failed: 0 });
});

// ── Events ──────────────────────────────────────────────────────────────────

// Thu 29 Oct 2026, 18:00-20:00 GMT.
const START = Date.UTC(2026, 9, 29, 18, 0);

function event(fields: StudioRow = {}): StudioRow {
  return {
    id: 'ev1',
    title: 'Gala',
    description: 'All welcome',
    location: 'Town Hall',
    branch_name: 'Chatham',
    sites: ['app'],
    start_time: at(START),
    end_time: at(START + 2 * 3_600_000),
    recurrence: null,
    recurrence_days: null,
    recurrence_until: null,
    created_at: at(NOW - MIN),
    updated_at: at(NOW - MIN),
    ...fields,
  };
}

test('event: new, then an unchanged save, a time change and a branch move', async () => {
  const h = harness({ events: [event()] });

  await runEventPush(h.deps, NOW);
  assert.equal(h.sent.length, 1);
  assert.deepEqual(h.sent[0], {
    audience: { condition: "'events' in topics && 'branch_chatham' in topics" },
    title: 'New event: Gala',
    body: 'Thu 29 Oct · 6:00 PM – 8:00 PM · Town Hall',
    data: {
      type: 'event',
      eventId: 'ev1',
      branch: 'Chatham',
      startTime: '2026-10-29T18:00:00.000Z',
      location: 'Town Hall',
    },
  });
  const q = h.urls[0];
  assert.equal(q.pathname, '/rest/v1/events');
  const from = at(NOW - 7 * MIN);
  assert.equal(q.searchParams.get('or'), `(updated_at.gt.${from},created_at.gt.${from})`);

  // The same row on the next poll, then a description-only save: nothing.
  await runEventPush(h.deps, NOW + 5 * MIN);
  h.tables.events = [event({ description: 'Bring a friend', updated_at: at(NOW + 6 * MIN) })];
  await runEventPush(h.deps, NOW + 10 * MIN);
  assert.equal(h.sent.length, 1);
  // The checkpoint moved on with each poll.
  assert.deepEqual(h.saved.get('events'), { checkedAt: NOW + 10 * MIN });

  // An hour later: "Event updated", led by what changed.
  h.tables.events = [event({ start_time: at(START + 3_600_000), updated_at: at(NOW + 11 * MIN) })];
  await runEventPush(h.deps, NOW + 15 * MIN);
  assert.equal(h.sent.length, 2);
  assert.equal(h.sent[1].title, 'Event updated: Gala');
  assert.equal(h.sent[1].body, 'Time changed: Thu 29 Oct · 7:00 PM – 8:00 PM · Town Hall');

  // Moved to Reading: Reading hears about it, and so does Chatham.
  h.tables.events = [
    event({
      start_time: at(START + 3_600_000),
      branch_name: 'Reading',
      updated_at: at(NOW + 16 * MIN),
    }),
  ];
  await runEventPush(h.deps, NOW + 20 * MIN);
  assert.equal(h.sent.length, 4);
  const [toNew, toOld] = h.sent.slice(2);
  assert.equal(condition(toNew), "'events' in topics && 'branch_reading' in topics");
  assert.equal(toNew.body, 'Branch changed: Thu 29 Oct · 7:00 PM – 8:00 PM · Town Hall');
  assert.equal(condition(toOld), "'events' in topics && 'branch_chatham' in topics");
  assert.equal(toOld.body, 'Moved to Reading: Thu 29 Oct · 7:00 PM – 8:00 PM · Town Hall');
  assert.equal(toOld.data.branch, 'Reading');

  // Overlapping polls see the move again: nothing more.
  await runEventPush(h.deps, NOW + 21 * MIN);
  assert.equal(h.sent.length, 4);
});

test('event for every branch goes to everyone with the Events toggle on', async () => {
  const h = harness({ events: [event({ branch_name: null })] });
  await runEventPush(h.deps, NOW);
  assert.equal(condition(h.sent[0]), "'events' in topics && 'all' in topics");
});

test('an older event seen for the first time is recorded silently, then its changes push', async () => {
  const old = { created_at: at(NOW - 30 * DAY), updated_at: at(NOW - MIN) };
  const h = harness({ events: [event(old)] });
  await runEventPush(h.deps, NOW);
  assert.equal(h.sent.length, 0);
  h.tables.events = [event({ ...old, location: 'Civic Centre', updated_at: at(NOW + MIN) })];
  await runEventPush(h.deps, NOW + 5 * MIN);
  assert.equal(h.sent.length, 1);
  assert.equal(h.sent[0].title, 'Event updated: Gala');
  assert.match(h.sent[0].body, /^Venue changed: .* · Civic Centre$/);
});

test('past events, website-only events and unpublished events are not pushed', async () => {
  const h = harness({
    events: [
      event({ id: 'past', start_time: at(NOW - 3 * DAY), end_time: at(NOW - 3 * DAY + 3_600_000) }),
      event({ id: 'website', sites: ['kharis', 'kp2'] }),
      event({ id: 'unpublished', sites: [] }),
      event({
        id: 'ended-weekly',
        recurrence: 'weekly',
        recurrence_days: [0],
        recurrence_until: '2026-10-20',
        start_time: at(Date.UTC(2026, 8, 6, 8, 0)),
      }),
    ],
  });
  assert.deepEqual(await runEventPush(h.deps, NOW), { sent: 0, failed: 0 });
});

test('a weekly event is dated at its next London occurrence', async () => {
  // First held Sun 6 Sep 2026, 09:00-12:00 BST; next is Sun 1 Nov, 09:00 GMT.
  const h = harness({
    events: [
      event({
        id: 'sunday',
        title: 'Sunday Service',
        location: 'Kensington Town Hall',
        recurrence: 'weekly',
        recurrence_days: [0],
        start_time: '2026-09-06T08:00:00+00:00',
        end_time: '2026-09-06T11:00:00+00:00',
      }),
    ],
  });
  await runEventPush(h.deps, NOW);
  assert.equal(h.sent.length, 1);
  assert.equal(h.sent[0].title, 'New event: Sunday Service');
  assert.equal(h.sent[0].body, 'Every Sunday · 9:00 AM – 12:00 PM · Kensington Town Hall');
  assert.equal(h.sent[0].data.startTime, '2026-11-01T09:00:00.000Z');

  // Adding Thursdays is a time change; the next occurrence is now Thu 29 Oct.
  h.tables.events = [
    { ...h.tables.events[0], recurrence_days: [0, 4], updated_at: at(NOW + MIN) },
  ];
  await runEventPush(h.deps, NOW + 5 * MIN);
  assert.equal(h.sent[1].body, 'Time changed: Every Sunday and Thursday · 9:00 AM – 12:00 PM · Kensington Town Hall');
  assert.equal(h.sent[1].data.startTime, '2026-10-29T09:00:00.000Z');
});

test('a failed event send keeps the checkpoint, and the next poll sends it', async () => {
  const h = harness({ events: [event()] });
  h.failSends(true);
  assert.deepEqual(await runEventPush(h.deps, NOW), { sent: 0, failed: 1 });
  assert.equal(h.saved.has('events'), false);
  h.failSends(false);
  assert.deepEqual(await runEventPush(h.deps, NOW + 5 * MIN), { sent: 1, failed: 0 });
  assert.equal(h.sent[0].title, 'New event: Gala');
});

// ── Branch services ─────────────────────────────────────────────────────────

function studio(service: StudioRow = {}, venue: StudioRow = {}) {
  return {
    branches: [
      { id: 'b1', slug: 'chatham', name: 'Chatham', is_active: true },
      { id: 'b2', slug: 'closed', name: 'Closed', is_active: false },
    ],
    services: [
      {
        id: 's1',
        branch_id: 'b1',
        venue_id: 'v1',
        name: 'Sunday Service',
        day: 'Sunday',
        start_time: '14:00:00',
        sort_order: 0,
        is_active: true,
        ...service,
      },
      // Inactive: never announced or reminded.
      {
        id: 's2',
        branch_id: 'b1',
        venue_id: 'v1',
        name: 'Old Service',
        day: 'Sunday',
        start_time: '14:00:00',
        is_active: false,
      },
    ],
    venues: [
      {
        id: 'v1',
        branch_id: 'b1',
        name: 'Hall',
        address_line1: '1 High St',
        address_line2: '1 High St, Rochester',
        city: 'Chatham',
        postcode: 'ME4 4AA',
        ...venue,
      },
    ],
  };
}

test('branch services: the first poll is silent, a real change pushes once', async () => {
  const h = harness(studio());
  assert.deepEqual(await runBranchUpdatePush(h.deps), { sent: 0, failed: 0 });
  assert.deepEqual(await runBranchUpdatePush(h.deps), { sent: 0, failed: 0 });

  Object.assign(h.tables, studio({ start_time: '15:00:00' }));
  assert.deepEqual(await runBranchUpdatePush(h.deps), { sent: 1, failed: 0 });
  assert.deepEqual(await runBranchUpdatePush(h.deps), { sent: 0, failed: 0 });
  assert.deepEqual(h.sent[0], {
    audience: { condition: "'service_reminders' in topics && 'branch_chatham' in topics" },
    title: 'Chatham: service details updated',
    body: 'We now meet Sundays 3:00 PM · 1 High St, Rochester, Chatham, ME4 4AA',
    data: {
      type: 'venue',
      branchId: 'chatham',
      branch: 'Chatham',
      address: '1 High St, Rochester, Chatham, ME4 4AA',
      schedule: 'Sundays 3:00 PM',
    },
  });

  Object.assign(h.tables, studio({ start_time: '15:00:00' }, { address_line1: '9 Low Rd' }));
  await runBranchUpdatePush(h.deps);
  assert.equal(h.sent.length, 2);
  assert.match(h.sent[1].body, /^We now meet Sundays 3:00 PM · 9 Low Rd/);
});

test('branch services: a failed send is retried by the next poll', async () => {
  const h = harness(studio());
  await runBranchUpdatePush(h.deps);
  Object.assign(h.tables, studio({ day: 'Saturday' }));
  h.failSends(true);
  assert.deepEqual(await runBranchUpdatePush(h.deps), { sent: 0, failed: 1 });
  h.failSends(false);
  assert.deepEqual(await runBranchUpdatePush(h.deps), { sent: 1, failed: 0 });
  assert.match(h.sent[0].body, /^We now meet Saturdays 2:00 PM/);
});

// ── Service reminders ───────────────────────────────────────────────────────

test('service reminder: an hour before a Studio service, once, in London time', async () => {
  // Sun 1 Nov 2026 is GMT: the 14:00 service is reminded at 13:00Z.
  const h = harness(studio());
  const due = Date.UTC(2026, 10, 1, 13, 0);
  assert.deepEqual(await runServiceReminderPush(h.deps, due - 15 * MIN), { sent: 0, failed: 0 });
  assert.deepEqual(await runServiceReminderPush(h.deps, due), { sent: 1, failed: 0 });
  // A late, retried run in the same window sends nothing more.
  assert.deepEqual(await runServiceReminderPush(h.deps, due + 5 * MIN), { sent: 0, failed: 0 });
  assert.deepEqual(h.sent, [
    {
      audience: { condition: "'service_reminders' in topics && 'branch_chatham' in topics" },
      title: 'Chatham: service at 2:00 PM',
      body: 'Starting in an hour at 1 High St, Rochester, Chatham, ME4 4AA. See you there.',
      data: {
        type: 'service_reminder',
        branchId: 'chatham',
        branch: 'Chatham',
        startTime: '2026-11-01T14:00:00.000Z',
        address: '1 High St, Rochester, Chatham, ME4 4AA',
      },
    },
  ]);
  const tables = h.urls.map((u) => `${u.pathname} ${u.searchParams.get('is_active') ?? ''}`.trim());
  assert.deepEqual(tables.slice(0, 3), [
    '/rest/v1/branches eq.true',
    '/rest/v1/services eq.true',
    '/rest/v1/venues',
  ]);
});

test('service reminder: a BST service and an unreadable one', async () => {
  // Sun 18 Oct 2026 is BST: the 10:00 service starts at 09:00Z.
  const h = harness(studio({ start_time: '10:00:00' }));
  assert.equal((await runServiceReminderPush(h.deps, Date.UTC(2026, 9, 18, 8, 0))).sent, 1);
  assert.equal(h.sent[0].data.startTime, '2026-10-18T09:00:00.000Z');

  const none = harness(studio({ day: 'Monthly' }));
  assert.equal((await runServiceReminderPush(none.deps, Date.UTC(2026, 9, 18, 8, 0))).sent, 0);
});
