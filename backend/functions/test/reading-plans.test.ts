import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  BIBLE_CHAPTERS,
  PlanEntry,
  ReadingPlanDoc,
  planEntry,
  resolveFromPlans,
} from '../src/reading-plans';

function plan(data: ReadingPlanDoc, id = 'p1'): PlanEntry {
  const entry = planEntry(id, data);
  assert.ok(entry, 'plan should be usable');
  return entry;
}

const twoCor = plan({
  title: '2 Corinthians',
  book: '2 Corinthians',
  startDate: '2026-09-17',
  days: 20,
  mode: 'chapter',
  startChapter: 1,
});

/** `YYYY-MM-DD` of day [n] (1-based) of a plan starting 2026-09-17. */
const dayDate = (n: number) =>
  new Date(Date.UTC(2026, 8, 17 + n - 1)).toISOString().slice(0, 10);

test('2 Corinthians chapters advance one a day up to chapter 13', () => {
  for (let n = 1; n <= 13; n++) {
    const r = resolveFromPlans([twoCor], dayDate(n));
    assert.equal(r?.reading.chapter, n, `day ${n}`);
    assert.equal(r?.planDay, n);
    assert.equal(r?.planDays, 20);
  }
});

test('day 14+ of a 2 Corinthians plan holds on chapter 13, never 14+', () => {
  for (let n = 14; n <= 20; n++) {
    const r = resolveFromPlans([twoCor], dayDate(n));
    assert.equal(r?.reading.book, '2 Corinthians');
    assert.equal(r?.reading.chapter, 13, `day ${n}`);
    assert.equal(r?.prayerReference, '2 Corinthians 13');
  }
});

test('a finished over-long plan pins its last day to the final chapter', () => {
  const r = resolveFromPlans([twoCor], '2026-11-01');
  assert.equal(r?.source, 'plan-last-day');
  assert.equal(r?.reading.chapter, 13);
  assert.equal(r?.planDay, 20);
});

test('a start chapter past the book is clamped to its last chapter', () => {
  const r = resolveFromPlans(
    [plan({ book: 'Jude', startDate: '2026-10-01', days: 3, startChapter: 4 })],
    '2026-10-02',
  );
  assert.equal(r?.reading.chapter, 1);
});

test('a book outside the table resolves unclamped', () => {
  const r = resolveFromPlans(
    [plan({ book: 'Psalm', startDate: '2026-10-01', days: 200, startChapter: 150 })],
    '2026-10-03',
  );
  assert.equal(r?.reading.chapter, 152);
});

test('chapter table matches the canonical 66-book counts', () => {
  assert.equal(Object.keys(BIBLE_CHAPTERS).length, 66);
  assert.equal(BIBLE_CHAPTERS['2 Corinthians'], 13);
  assert.equal(BIBLE_CHAPTERS.Psalms, 150);
  assert.equal(
    Object.values(BIBLE_CHAPTERS).reduce((a, b) => a + b, 0),
    1189,
  );
});
