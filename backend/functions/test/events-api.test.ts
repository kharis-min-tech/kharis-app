import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { EventRecord, pickEvents } from '../src/events-api';
import { EventDoc } from '../src/types';

const NOW = Date.UTC(2026, 9, 3, 12, 0);
const HOUR = 3_600_000;

function ev(id: string, startH: number, fields: Partial<EventDoc> & { endH?: number } = {}): EventRecord {
  const { endH, ...rest } = fields;
  return {
    id,
    data: {
      title: id,
      startTime: Timestamp.fromMillis(NOW + startH * HOUR),
      ...(endH === undefined ? {} : { endTime: Timestamp.fromMillis(NOW + endH * HOUR) }),
      ...rest,
    },
  };
}

const ids = (list: { id: string }[]) => list.map((e) => e.id);

test('branch scope includes explicit-null, blank and keyless all-campus events', () => {
  const own = ev('own', 5, { branch: 'Chatham' });
  const other = ev('other', 1, { branch: 'Reading' });
  const nul = ev('null', 2, { branch: null });
  const blank = ev('blank', 3, { branch: '' });
  const keyless = ev('keyless', 4);
  const picked = pickEvents('Chatham', [own], [other, nul, blank, keyless, own], false, 50, NOW);
  assert.deepEqual(ids(picked), ['null', 'blank', 'keyless', 'own']);
});

test('no branch returns every campus', () => {
  const docs = [ev('a', 1, { branch: 'Reading' }), ev('b', 2)];
  assert.deepEqual(ids(pickEvents(undefined, [], docs, false, 50, NOW)), ['a', 'b']);
});

test('hidden tombstones of deleted website events are never served', () => {
  const gone = ev('web_1', 1, { hidden: true, branch: 'Chatham' });
  const goneAll = ev('web_2', 2, { hidden: true });
  const kept = ev('web_3', 3);
  assert.deepEqual(ids(pickEvents('Chatham', [gone], [gone, goneAll, kept], false, 50, NOW)), ['web_3']);
  assert.deepEqual(ids(pickEvents(undefined, [], [gone, goneAll, kept], false, 50, NOW)), ['web_3']);
});

test('upcoming keeps an event that started but has not finished', () => {
  const running = ev('running', -2, { endH: 1 });
  const over = ev('over', -3, { endH: -1 });
  const instant = ev('instant-past', -1);
  const picked = pickEvents(undefined, [], [over, running, instant, ev('soon', 1)], false, 50, NOW);
  assert.deepEqual(ids(picked), ['running', 'soon']);
});

test('past is decided by the effective end and is most recent first, capped', () => {
  const docs = [ev('old', -48, { endH: -47 }), ev('recent', -5, { endH: -4 }), ev('running', -2, { endH: 1 })];
  assert.deepEqual(ids(pickEvents(undefined, [], docs, true, 50, NOW)), ['recent', 'old']);
  assert.deepEqual(ids(pickEvents(undefined, [], docs, true, 1, NOW)), ['recent']);
});

test('a campus event in both queries is listed once; address is served', () => {
  const own = ev('own', 2, { branch: 'Chatham', location: 'Hall', address: '1 High St' });
  const picked = pickEvents('Chatham', [own], [own], false, 50, NOW);
  assert.equal(picked.length, 1);
  assert.equal(picked[0].location, 'Hall');
  assert.equal(picked[0].address, '1 High St');
});
