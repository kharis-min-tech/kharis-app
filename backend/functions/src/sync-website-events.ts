import { onSchedule } from 'firebase-functions/v2/scheduler';
import {
  DocumentData,
  FieldValue,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import { decodeHtmlEntities, htmlToText } from './html-text';
import { LONDON, londonClock, londonWallTime } from './london-time';
import { slugifyBranch } from './topics';

/**
 * Imports upcoming events from the church website (finding A1) into
 * `events/web_<wpId>`, so the app's Events tab matches kharis.org.
 *
 * Source: the site runs EventON Lite. Event times are NOT in the WordPress
 * REST API (`/wp-json/wp/v2/ajde_events` has no start/end), so they come from
 * the same AJAX endpoint the K-Events page uses
 * (`POST /?evo-ajax=eventon_get_events`, one month per call, with the public
 * nonce and calendar shortcode embedded in that page). The campus comes from
 * the `event_type` taxonomy ("Kharis London" -> branch "London"), read through
 * the REST API together with the description.
 *
 * Idempotent: doc ids are derived from the WordPress post id (plus the repeat
 * index for repeating events), unchanged events are not rewritten, and a site
 * event that disappears is deleted only if it was still upcoming. An admin's
 * branch, banner image and featured flag survive every re-sync, and so does a
 * Studio delete: it leaves a `hidden: true` tombstone (deleting the doc would
 * only have it recreated next hour) that the sync never rewrites and every
 * reader filters out.
 */

const SITE = 'https://kharis.org';
const CALENDAR_PAGE = `${SITE}/k-events/`;
const EVENTON_ENDPOINT = `${SITE}/?evo-ajax=eventon_get_events`;
const REST = `${SITE}/wp-json/wp/v2`;

/** The current month plus this many following months are imported. */
const MONTHS_AHEAD = 2;

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

/** Marks docs this job owns (`events.source`). */
export const WEBSITE_SOURCE = 'website';

/** One occurrence of a website event. */
export interface WebsiteEvent {
  wpId: number;
  /** EventON repeat index; '0' for a one-off event. */
  ri: string;
  title: string;
  startMs: number;
  endMs: number;
  location: string | null;
  address: string | null;
  imageUrl: string | null;
}

export interface CalendarConfig {
  nonce: string;
  shortcode: Record<string, unknown>;
}

/** The EventON nonce and calendar shortcode embedded in the K-Events page. */
export function parseCalendarConfig(html: string): CalendarConfig | null {
  const nonce = /"n":"([0-9a-f]+)"/.exec(html)?.[1];
  const sc = /data-sc='([^']*)'/.exec(html)?.[1];
  if (!nonce || !sc) return null;
  try {
    return { nonce, shortcode: JSON.parse(decodeHtmlEntities(sc)) };
  } catch {
    return null;
  }
}

/** Form body asking EventON for one London calendar month. */
export function monthRequestBody(
  config: CalendarConfig,
  year: number,
  month: number,
): URLSearchParams {
  const start = londonWallTime(year, month, 1, 0);
  const end = londonWallTime(year, month + 1, 1, 0) - 1000;
  const shortcode: Record<string, unknown> = {
    ...config.shortcode,
    fixed_month: String(month),
    fixed_year: String(year),
    focus_start_date_range: String(Math.floor(start / 1000)),
    focus_end_date_range: String(Math.floor(end / 1000)),
  };
  const body = new URLSearchParams({
    direction: 'none',
    ajaxtype: 'switchmonth',
    nonce: config.nonce,
  });
  for (const [key, value] of Object.entries(shortcode)) {
    body.append(`shortcode[${key}]`, String(value ?? ''));
  }
  return body;
}

interface EventonJsonEvent {
  event_id?: number | string;
  ri?: string | number;
  event_title?: string;
  unix_start?: string | number;
  unix_end?: string | number;
}

/** Attribute value in an HTML fragment, decoded; null when absent or blank. */
function attr(html: string, name: string): string | null {
  const value = new RegExp(`${name}="([^"]*)"`).exec(html)?.[1];
  const text = value === undefined ? '' : decodeHtmlEntities(value).trim();
  return text || null;
}

/**
 * Website events in one `eventon_get_events` response. Times come from the
 * JSON (`unix_start`/`unix_end` are true UTC seconds; `evcal_srow` is local
 * wall time and must not be used); venue and banner from that occurrence's
 * HTML block.
 */
export function parseEventonResponse(response: {
  html?: string;
  json?: EventonJsonEvent[] | null;
}): WebsiteEvent[] {
  const html = response.html ?? '';
  const blocks: Record<string, string> = {};
  for (const match of html.matchAll(/<div id="event_(\d+)_(\d+)"[\s\S]*?(?=<div id="event_\d+_\d+"|$)/g)) {
    blocks[`${match[1]}_${match[2]}`] = match[0];
  }

  const events: WebsiteEvent[] = [];
  for (const raw of response.json ?? []) {
    const wpId = Number(raw.event_id);
    const startMs = Number(raw.unix_start) * 1000;
    const endMs = Number(raw.unix_end) * 1000;
    const title = decodeHtmlEntities(String(raw.event_title ?? '')).trim();
    if (!Number.isInteger(wpId) || !title || !Number.isFinite(startMs) || startMs <= 0) {
      continue;
    }
    const ri = String(raw.ri ?? '0').replace(/\D/g, '') || '0';
    const block = blocks[`${wpId}_${ri}`] ?? '';
    const image = /background-image:\s*url\(['"]?([^'")]+)['"]?\)/.exec(block)?.[1] ?? null;
    events.push({
      wpId,
      ri,
      title,
      startMs,
      endMs: Number.isFinite(endMs) && endMs >= startMs ? endMs : startMs,
      location: attr(block, 'data-location_name'),
      address: attr(block, 'data-location_address'),
      imageUrl: image && /^https?:\/\//.test(image) ? image : null,
    });
  }
  return events;
}

/**
 * Campuses (Firestore branch names) an event belongs to, from its EventON
 * `event_type` names. "Kharis London" -> "London", "KP2 London" stays as is;
 * matched case-insensitively against the real branch list.
 *
 * `campuses` is `[null]` (all-campus) for an event with no campus term. Any
 * term naming a campus the app does not have lands in `unknown`, and the
 * caller skips the event: importing it as all-campus would push it to every
 * member in the church.
 */
export function campusesFor(
  termNames: string[],
  branchNames: string[],
): { campuses: Array<string | null>; unknown: string[] } {
  if (termNames.length === 0) return { campuses: [null], unknown: [] };
  const byKey: Record<string, string> = {};
  for (const name of branchNames) byKey[name.trim().toLowerCase()] = name;

  const campuses: string[] = [];
  const unknown: string[] = [];
  for (const term of termNames) {
    const name = decodeHtmlEntities(term).trim();
    const match =
      byKey[name.toLowerCase()] ?? byKey[name.replace(/^kharis\s+/i, '').toLowerCase()];
    if (match === undefined) unknown.push(name);
    else if (!campuses.includes(match)) campuses.push(match);
  }
  return { campuses, unknown };
}

/** `events` doc id for one occurrence at one campus. */
export function webEventDocId(
  event: Pick<WebsiteEvent, 'wpId' | 'ri'>,
  campus: string | null,
  multiCampus: boolean,
): string {
  const repeat = event.ri === '0' ? '' : `_${event.ri}`;
  const scope = multiCampus && campus ? `_${slugifyBranch(campus)}` : '';
  return `web_${event.wpId}${repeat}${scope}`;
}

/** Fields the website owns; re-written whenever the site changes them. */
export function siteFields(
  event: WebsiteEvent,
  description: string | null,
  sourceUrl: string | null,
): DocumentData {
  return {
    title: event.title,
    description,
    location: event.location,
    address: event.address,
    startTime: Timestamp.fromMillis(event.startMs),
    endTime: Timestamp.fromMillis(event.endMs),
    source: WEBSITE_SOURCE,
    sourceId: event.wpId,
    sourceUrl,
  };
}

/** The [fields] whose stored value differs (Timestamp-aware). */
export function changedFields(stored: DocumentData, fields: DocumentData): DocumentData {
  const changed: DocumentData = {};
  for (const [key, value] of Object.entries(fields)) {
    const prev = stored[key];
    const same =
      value instanceof Timestamp && prev instanceof Timestamp
        ? value.isEqual(prev)
        : (prev ?? null) === (value ?? null);
    if (!same) changed[key] = value;
  }
  return changed;
}

/** What the sync does to one occurrence's `events` doc. */
export type WebEventWrite =
  | { kind: 'create' }
  | { kind: 'update'; changed: DocumentData }
  | { kind: 'keep' };

/**
 * Create a missing doc, rewrite the site fields that changed, or leave it.
 * A hidden doc is an admin's delete and is never touched: rewriting it would
 * fire the event-change push for an event the admin removed.
 */
export function webEventWrite(
  stored: DocumentData | undefined,
  fields: DocumentData,
): WebEventWrite {
  if (stored === undefined) return { kind: 'create' };
  if (stored.hidden === true) return { kind: 'keep' };
  const changed = changedFields(stored, fields);
  return Object.keys(changed).length === 0 ? { kind: 'keep' } : { kind: 'update', changed };
}

async function request(url: string, init?: RequestInit): Promise<Response> {
  const res = await fetch(url, {
    ...init,
    headers: { 'User-Agent': USER_AGENT, Accept: 'application/json', ...init?.headers },
  });
  if (!res.ok) throw new Error(`${url} -> HTTP ${res.status}`);
  return res;
}

async function getJson<T>(url: string, init?: RequestInit): Promise<T> {
  return (await (await request(url, init)).json()) as T;
}

/**
 * Every page of a WordPress REST collection ([url] already has a query
 * string). A page cap of `per_page=100` silently drops the rest, so the
 * `X-WP-TotalPages` header is followed to the end.
 */
export async function getAllPages<T>(url: string): Promise<T[]> {
  const items: T[] = [];
  for (let page = 1; ; page++) {
    const res = await request(`${url}&page=${page}`);
    items.push(...((await res.json()) as T[]));
    const totalPages = Number(res.headers.get('x-wp-totalpages') ?? '1');
    if (!(page < totalPages)) return items;
  }
}

/** WordPress allows at most this many ids in one `include=` page. */
const WP_PAGE_SIZE = 100;

export interface WpEvent {
  id: number;
  link?: string;
  event_type?: number[];
  content?: { rendered?: string };
}

/**
 * Campuses for one occurrence, or why it must be skipped. An occurrence
 * whose post the REST API did not return, or whose `event_type` ids it could
 * not name, has unknown campuses: importing it as all-campus would push it to
 * every member in the church.
 */
export function eventCampuses(
  post: WpEvent | undefined,
  termName: Record<number, string>,
  branchNames: string[],
): { campuses: Array<string | null>; skip: string | null } {
  if (!post) return { campuses: [], skip: 'post not returned by the REST API' };
  const ids = post.event_type ?? [];
  const unresolved = ids.filter((id) => termName[id] === undefined);
  if (unresolved.length > 0) {
    return { campuses: [], skip: `unresolved event_type ${unresolved.join(', ')}` };
  }
  const { campuses, unknown } = campusesFor(
    ids.map((id) => termName[id]),
    branchNames,
  );
  if (unknown.length > 0) return { campuses: [], skip: `unknown campus ${unknown.join(', ')}` };
  return { campuses, skip: null };
}

export const syncWebsiteEvents = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: LONDON,
    memory: '256MiB',
    timeoutSeconds: 120,
  },
  async () => {
    const db = getFirestore();
    const nowMs = Date.now();

    const pageRes = await fetch(CALENDAR_PAGE, { headers: { 'User-Agent': USER_AGENT } });
    if (!pageRes.ok) throw new Error(`${CALENDAR_PAGE} -> HTTP ${pageRes.status}`);
    const config = parseCalendarConfig(await pageRes.text());
    if (!config) throw new Error('K-Events page has no EventON calendar config');

    // Any failed month aborts the run BEFORE deletions, so a site hiccup can
    // never empty the Events tab.
    const today = londonClock(nowMs);
    const occurrences: WebsiteEvent[] = [];
    for (let i = 0; i <= MONTHS_AHEAD; i++) {
      const year = today.year + Math.floor((today.month - 1 + i) / 12);
      const month = ((today.month - 1 + i) % 12) + 1;
      const response = await getJson<{ html?: string; json?: EventonJsonEvent[] }>(
        EVENTON_ENDPOINT,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: monthRequestBody(config, year, month).toString(),
        },
      );
      occurrences.push(...parseEventonResponse(response).filter((e) => e.endMs >= nowMs));
    }

    const wpIds = [...new Set(occurrences.map((e) => e.wpId))];
    const idPages: number[][] = [];
    for (let i = 0; i < wpIds.length; i += WP_PAGE_SIZE) {
      idPages.push(wpIds.slice(i, i + WP_PAGE_SIZE));
    }
    const [terms, postPages, branchSnap] = await Promise.all([
      getAllPages<{ id: number; name: string }>(
        `${REST}/event_type?per_page=${WP_PAGE_SIZE}&_fields=id,name`,
      ),
      Promise.all(
        idPages.map((ids) =>
          getAllPages<WpEvent>(
            `${REST}/ajde_events?per_page=${WP_PAGE_SIZE}&include=${ids.join(',')}` +
              '&_fields=id,link,event_type,content',
          ),
        ),
      ),
      db.collection('branches').get(),
    ]);
    const termName: Record<number, string> = {};
    for (const term of terms) termName[term.id] = term.name;
    const postById: Record<number, WpEvent> = {};
    for (const post of postPages.flat()) postById[post.id] = post;
    const branchNames = branchSnap.docs
      .map((d) => (d.data().name ?? '').toString())
      .filter((n) => n.trim());

    const seen = new Set<string>();
    let created = 0;
    let updated = 0;
    let skipped = 0;
    for (const event of occurrences) {
      const post = postById[event.wpId];
      const { campuses, skip } = eventCampuses(post, termName, branchNames);
      if (skip !== null) {
        console.warn(`[web-events] skip ${event.wpId}: ${skip}`);
        skipped++;
        continue;
      }
      const description = post?.content?.rendered ? htmlToText(post.content.rendered) || null : null;
      const fields = siteFields(event, description?.slice(0, 2000) ?? null, post?.link ?? null);

      for (const campus of campuses) {
        const id = webEventDocId(event, campus, campuses.length > 1);
        seen.add(id);
        const ref = db.collection('events').doc(id);
        const snap = await ref.get();
        // branch, imageUrl and isFeatured are the admin's to change.
        const write = webEventWrite(snap.exists ? snap.data() ?? {} : undefined, fields);
        if (write.kind === 'create') {
          await ref.set({
            ...fields,
            branch: campus,
            imageUrl: event.imageUrl,
            isFeatured: false,
            createdAt: FieldValue.serverTimestamp(),
            syncedAt: FieldValue.serverTimestamp(),
          });
          created++;
        } else if (write.kind === 'update') {
          await ref.update({ ...write.changed, syncedAt: FieldValue.serverTimestamp() });
          updated++;
        }
      }
    }

    // Upcoming imports that are no longer on the site were cancelled there.
    const stale = await db
      .collection('events')
      .where('source', '==', WEBSITE_SOURCE)
      .get();
    let deleted = 0;
    for (const doc of stale.docs) {
      const start = doc.data().startTime;
      if (seen.has(doc.id) || !(start instanceof Timestamp) || start.toMillis() < nowMs) continue;
      const startMonth = londonClock(start.toMillis());
      const monthsOut =
        (startMonth.year - today.year) * 12 + (startMonth.month - today.month);
      if (monthsOut > MONTHS_AHEAD) continue;
      await doc.ref.delete();
      deleted++;
    }

    console.log(
      `[web-events] ${occurrences.length} upcoming on site: ` +
        `${created} created, ${updated} updated, ${deleted} deleted, ${skipped} skipped`,
    );
  },
);
