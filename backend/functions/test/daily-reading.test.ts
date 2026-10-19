import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CONTENT_STUDIO_KEY,
  ReadingLookup,
  ReadingPushDeps,
  ReadingPushMessage,
  fetchStudioReading,
  pickReading,
  runDailyReadingPush,
} from '../src/daily-reading';

const DATE = '2026-10-18';

interface Call {
  url: string;
  headers: Record<string, string>;
}

/** A `fetch` answering [status] with [body], recording each request. */
function mockFetch(status: number, body: unknown) {
  const calls: Call[] = [];
  const fetchImpl = (async (url: string, init?: RequestInit) => {
    // The module only ever passes a plain header object.
    const headers = (init?.headers ?? {}) as Record<string, string>;
    calls.push({ url, headers });
    return new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    });
  }) as unknown as typeof fetch;
  return { fetchImpl, calls };
}

function row(fields: Record<string, unknown>) {
  return {
    id: 'r1',
    workspace: 'general',
    kind: 'reading',
    date: DATE,
    title: 'Grace',
    body: '',
    reference: 'John 3:16-18',
    ...fields,
  };
}

/** The fields a run writes on `dailyReadingPushes/{date}`. */
interface ClaimDoc {
  date?: string;
  skipped?: string;
  pushMessageId?: string;
  reference?: string;
  workspace?: string;
  pushError?: string;
}

/** In-memory claim store shared across runs, like `dailyReadingPushes`. */
function harness(lookup: () => Promise<ReadingLookup>, claims = new Map<string, ClaimDoc>()) {
  const sent: ReadingPushMessage[] = [];
  const deps = (date: string): ReadingPushDeps => ({
    claim: async () => {
      if (claims.has(date)) return false;
      claims.set(date, { date });
      return true;
    },
    lookup,
    send: async (message) => {
      sent.push(message);
      return `msg-${sent.length}`;
    },
    recordSkipped: async (skipped) => {
      claims.set(date, { ...claims.get(date), skipped });
    },
    recordSent: async (pushMessageId, reference, workspace) => {
      claims.set(date, { ...claims.get(date), pushMessageId, reference, workspace });
    },
    recordError: async (e) => {
      claims.set(date, { ...claims.get(date), pushError: String(e) });
    },
  });
  return { sent, claims, deps };
}

test('queries today\'s readings in the app and general workspaces with the publishable key', async () => {
  const { fetchImpl, calls } = mockFetch(200, [row({})]);
  await fetchStudioReading(DATE, fetchImpl);
  assert.equal(calls.length, 1);
  const url = new URL(calls[0].url);
  assert.equal(url.origin + url.pathname, 'https://cqgyiqxhpxwasogpdghx.supabase.co/rest/v1/daily_entries');
  assert.equal(url.searchParams.get('kind'), 'eq.reading');
  assert.equal(url.searchParams.get('date'), `eq.${DATE}`);
  assert.equal(url.searchParams.get('workspace'), 'in.(app,general)');
  assert.equal(calls[0].headers.apikey, CONTENT_STUDIO_KEY);
  assert.equal(calls[0].headers.Authorization, `Bearer ${CONTENT_STUDIO_KEY}`);
});

test('a Studio row is pushed with its reference', async () => {
  const { fetchImpl } = mockFetch(200, [row({ reference: '2 Corinthians 13' })]);
  const { sent, claims, deps } = harness(() => fetchStudioReading(DATE, fetchImpl));
  assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'sent');
  assert.deepEqual(sent, [
    {
      title: "Today's Bible reading",
      body: '2 Corinthians 13',
      data: { type: 'reading', date: DATE, reference: '2 Corinthians 13' },
    },
  ]);
  assert.deepEqual(claims.get(DATE), {
    date: DATE,
    pushMessageId: 'msg-1',
    reference: '2 Corinthians 13',
    workspace: 'general',
  });
});

test('the title is the body when the row has no reference', async () => {
  const { fetchImpl } = mockFetch(200, [row({ reference: '  ', title: 'Psalm of trust' })]);
  const { sent, deps } = harness(() => fetchStudioReading(DATE, fetchImpl));
  await runDailyReadingPush(DATE, deps(DATE));
  assert.equal(sent[0].body, 'Psalm of trust');
  assert.equal(sent[0].data.reference, 'Psalm of trust');
});

test('the app workspace beats general, whatever the row order', () => {
  const rows = [
    row({ workspace: 'general', reference: 'Romans 8' }),
    row({ workspace: 'app', reference: 'John 1' }),
  ];
  assert.deepEqual(pickReading(rows, DATE), {
    title: 'Grace',
    reference: 'John 1',
    workspace: 'app',
  });
});

test('rows that are not today\'s titled reading in an app workspace are ignored', () => {
  assert.equal(pickReading([row({ kind: 'prayer' })], DATE), null);
  assert.equal(pickReading([row({ workspace: 'kharis' })], DATE), null);
  assert.equal(pickReading([row({ date: '2026-10-17' })], DATE), null);
  assert.equal(pickReading([row({ title: '   ' })], DATE), null);
  assert.equal(pickReading([null, 'x', 3], DATE), null);
  // An untitled app row does not hide a titled general one.
  assert.equal(
    pickReading([row({ workspace: 'app', title: '' }), row({ reference: 'Acts 2' })], DATE)
      ?.reference,
    'Acts 2',
  );
});

for (const [name, status, body] of [
  ['no row', 200, []],
  ['table missing (404)', 404, { code: '42P01', message: 'relation "public.daily_entries" does not exist' }],
  ['rejected query (400)', 400, { message: 'bad column' }],
  ['server error', 503, { message: 'unavailable' }],
  ['non-array body', 200, { rows: [] }],
] as const) {
  test(`${name}: skipped, recorded on the claim, nothing sent`, async () => {
    const { fetchImpl } = mockFetch(status, body);
    const { sent, claims, deps } = harness(() => fetchStudioReading(DATE, fetchImpl));
    assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'skipped');
    assert.equal(sent.length, 0);
    assert.equal(typeof claims.get(DATE)?.skipped, 'string');
  });
}

test('a network failure is skipped, not thrown', async () => {
  const fetchImpl = (async () => {
    throw new TypeError('fetch failed');
  }) as unknown as typeof fetch;
  const lookup = await fetchStudioReading(DATE, fetchImpl);
  assert.equal(lookup.reading, null);
  const { sent, deps } = harness(async () => lookup);
  assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'skipped');
  assert.equal(sent.length, 0);
});

test('never sends twice for one date: a re-run finds the claim and does nothing', async () => {
  const { fetchImpl, calls } = mockFetch(200, [row({})]);
  const { sent, deps } = harness(() => fetchStudioReading(DATE, fetchImpl));
  assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'sent');
  assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'already-claimed');
  assert.equal(sent.length, 1);
  assert.equal(calls.length, 1);
});

test('a skipped day stays skipped when the reading appears later that day', async () => {
  let rows: unknown[] = [];
  const { sent, deps } = harness(async () => {
    const { fetchImpl } = mockFetch(200, rows);
    return fetchStudioReading(DATE, fetchImpl);
  });
  assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'skipped');
  rows = [row({})];
  assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'already-claimed');
  assert.equal(sent.length, 0);
});

test('a failed send records the error and keeps the claim', async () => {
  const claims = new Map<string, ClaimDoc>();
  const { deps } = harness(async () => ({ reading: { title: 'T', reference: 'Mark 1', workspace: 'app' } }), claims);
  const failing: ReadingPushDeps = {
    ...deps(DATE),
    send: async () => {
      throw new Error('messaging/unavailable');
    },
  };
  assert.equal(await runDailyReadingPush(DATE, failing), 'failed');
  assert.match(claims.get(DATE)?.pushError ?? '', /messaging\/unavailable/);
  assert.equal(await runDailyReadingPush(DATE, deps(DATE)), 'already-claimed');
});
