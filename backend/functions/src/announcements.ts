import { Timestamp } from 'firebase-admin/firestore';
import { NewsDoc } from './types';

/** JSON shape returned by getAnnouncements. `branch: null` = all-campus. */
export interface AnnouncementJson {
  id: string;
  title: string;
  body: string;
  type: string;
  branch: string | null;
  imageUrl: string | null;
  publishedAt: string | null;
  expiresAt: string | null;
  /** `events/{eventId}` the announcement promotes, or null. */
  eventId: string | null;
  /** Optional call-to-action link and its button label. */
  linkUrl: string | null;
  ctaLabel: string | null;
}

/** A `news` document as read from Firestore: id plus raw data. */
export interface NewsRecord {
  id: string;
  data: NewsDoc;
}

/** Trimmed text, or null for null/absent/blank: how every optional field reads. */
export const blankToNull = (value: unknown): string | null => {
  const text = (value ?? '').toString().trim();
  return text ? text : null;
};

const iso = (value: unknown): string | null =>
  value instanceof Timestamp ? value.toDate().toISOString() : null;

export function toAnnouncement({ id, data }: NewsRecord): AnnouncementJson {
  return {
    id,
    title: data.title ?? '',
    body: data.body ?? '',
    // An announcement is a message, never an event. Legacy docs typed 'Event'
    // by the old admin dropdown are surfaced as announcements so nothing in
    // the app can render a `news` doc as a dated, RSVP-able occurrence.
    type: data.type && data.type !== 'Event' ? data.type : 'Announcement',
    branch: blankToNull(data.branch),
    imageUrl: blankToNull(data.imageUrl),
    publishedAt: iso(data.publishedAt),
    // null means "never expires".
    expiresAt: iso(data.expiresAt),
    eventId: blankToNull(data.eventId),
    linkUrl: blankToNull(data.linkUrl),
    ctaLabel: blankToNull(data.linkUrl) ? blankToNull(data.ctaLabel) ?? 'Learn more' : null,
  };
}

/**
 * What a member may see at [nowMs]: published (a Studio-scheduled future
 * `publishedAt` stays hidden until it arrives) and not yet expired. The one
 * rule shared by getAnnouncements and the push poller, so a notice is never
 * pushed that the API would then refuse to show, or shown before its time.
 */
export function isLiveNews(data: NewsDoc, nowMs: number): boolean {
  const pub = data.publishedAt;
  if (!(pub instanceof Timestamp) || pub.toMillis() > nowMs) return false;
  const exp = data.expiresAt;
  return !(exp instanceof Timestamp) || exp.toMillis() > nowMs;
}

/** True for a doc with no campus: null, absent or blank `branch`. */
export function isAllCampus(data: { branch?: unknown }): boolean {
  return blankToNull(data.branch) === null;
}

const BY_NEWEST = (a: AnnouncementJson, b: AnnouncementJson) =>
  Date.parse(b.publishedAt ?? '') - Date.parse(a.publishedAt ?? '');

/**
 * The announcements a member at [branch] should see, newest first.
 *
 * [branchDocs] are the newest docs whose `branch` equals [branch];
 * [anyDocs] the newest docs of any campus. Branch-scoped notices are selected
 * BEFORE all-campus ones and only then is the page re-sorted for display: a
 * campus notice is the most relevant thing a member can be shown, so it must
 * never be crowded off the page by newer church-wide items.
 *
 * The all-campus half is picked from [anyDocs] in memory because docs created
 * before the portal gained a branch field carry no `branch` key at all, and a
 * Firestore equality filter never matches a missing field.
 *
 * With no [branch] the plain church-wide feed (every campus) is returned.
 */
export function pickAnnouncements(
  branch: string | undefined,
  branchDocs: NewsRecord[],
  anyDocs: NewsRecord[],
  limit: number,
  nowMs: number,
): AnnouncementJson[] {
  const live = (docs: NewsRecord[]) =>
    docs
      .filter((d) => isLiveNews(d.data, nowMs))
      .map(toAnnouncement)
      .sort(BY_NEWEST);

  if (!branch) return live(anyDocs).slice(0, limit);

  const scoped = live(branchDocs).slice(0, limit);
  const seen = new Set(scoped.map((a) => a.id));
  const campus = live(anyDocs.filter((d) => isAllCampus(d.data)))
    .filter((a) => !seen.has(a.id))
    .slice(0, limit - scoped.length);
  return [...scoped, ...campus].sort(BY_NEWEST);
}

/**
 * The poller's pick: live notices published inside the last [windowMs] that
 * have not been pushed yet. Scheduled notices become due when their
 * `publishedAt` arrives, never before.
 */
export function isPushDue(
  data: NewsDoc & { pushedAt?: unknown },
  nowMs: number,
  windowMs: number,
): boolean {
  if (data.pushedAt) return false;
  if (!isLiveNews(data, nowMs)) return false;
  return (data.publishedAt as Timestamp).toMillis() >= nowMs - windowMs;
}
