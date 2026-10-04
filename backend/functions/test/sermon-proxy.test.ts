import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { Response } from 'express';
import {
  BROWSER_USER_AGENT,
  SERMON_API_UPSTREAM,
  SERMON_PROXY_CACHE_CONTROL,
  handleSermonProxy,
} from '../src/sermon-proxy';

interface Captured {
  status?: number;
  headers: Record<string, string>;
  body?: unknown;
}

function fakeRes(): { res: Response; out: Captured } {
  const out: Captured = { headers: {} };
  const res = {
    status(code: number) {
      out.status = code;
      return this;
    },
    set(name: string, value: string) {
      out.headers[name] = value;
      return this;
    },
    send(body: unknown) {
      out.body = body;
      return this;
    },
    json(body: unknown) {
      out.body = body;
      return this;
    },
  };
  // Only the members the handler calls are implemented.
  return { res: res as unknown as Response, out };
}

const req = (method: string, path: string, url: string) => ({
  method,
  path,
  url,
  get: () => 'us-central1-kharis-app-47c49.cloudfunctions.net',
});

function mockFetch(status: number, body: string) {
  const calls: Array<{ url: string; init?: RequestInit }> = [];
  const fetchImpl = (async (url: string, init?: RequestInit) => {
    calls.push({ url, init });
    return new Response(body, { status, headers: { 'content-type': 'application/json' } });
  }) as unknown as typeof fetch;
  return { fetchImpl, calls };
}

test('forwards sermons/ with the query string and a browser user agent', async () => {
  const page = JSON.stringify({
    count: 1489,
    next: `${SERMON_API_UPSTREAM}sermons/?page=3&search=grace`,
    results: [],
  });
  const { fetchImpl, calls } = mockFetch(200, page);
  const { res, out } = fakeRes();
  await handleSermonProxy(req('GET', '/sermons/', '/sermons/?page=2&search=grace'), res, fetchImpl);

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, `${SERMON_API_UPSTREAM}sermons/?page=2&search=grace`);
  const headers = calls[0].init?.headers as Record<string, string>;
  assert.equal(headers['User-Agent'], BROWSER_USER_AGENT);
  assert.equal(out.status, 200);
  assert.equal(out.headers['Cache-Control'], SERMON_PROXY_CACHE_CONTROL);
  assert.equal(out.headers['Content-Type'], 'application/json');
  // `next` now points back at the proxy, so a web client stays on it.
  const next = JSON.parse(String(out.body)).next as string;
  assert.equal(
    next,
    'https://us-central1-kharis-app-47c49.cloudfunctions.net/sermonApiProxy/sermons/?page=3&search=grace',
  );
});

test('forwards series/ and playlists/<id>/', async () => {
  for (const path of ['/series/', '/playlists/12/']) {
    const { fetchImpl, calls } = mockFetch(200, '{}');
    const { res } = fakeRes();
    await handleSermonProxy(req('GET', path, path), res, fetchImpl);
    assert.equal(calls[0].url, `${SERMON_API_UPSTREAM}${path.slice(1)}`);
  }
});

test('refuses other paths and methods without calling upstream', async () => {
  for (const [method, path] of [
    ['GET', '/preachers/'],
    ['GET', '/sermons/../admin/'],
    ['GET', '/sermons'],
    ['POST', '/sermons/'],
  ]) {
    const { fetchImpl, calls } = mockFetch(200, '{}');
    const { res, out } = fakeRes();
    await handleSermonProxy(req(method, path, path), res, fetchImpl);
    assert.equal(calls.length, 0, `${method} ${path}`);
    assert.ok(out.status === 404 || out.status === 405);
  }
});

test('passes an upstream 404 through uncached; network failure is a 502', async () => {
  const { fetchImpl } = mockFetch(404, '{"detail":"Invalid page."}');
  const { res, out } = fakeRes();
  await handleSermonProxy(req('GET', '/sermons/', '/sermons/?page=31'), res, fetchImpl);
  assert.equal(out.status, 404);
  assert.equal(out.headers['Cache-Control'], 'no-store');

  const failing = (async () => {
    throw new Error('ECONNRESET');
  }) as unknown as typeof fetch;
  const broken = fakeRes();
  await handleSermonProxy(req('GET', '/sermons/', '/sermons/'), broken.res, failing);
  assert.equal(broken.out.status, 502);
});
