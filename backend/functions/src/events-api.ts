import { Timestamp } from 'firebase-admin/firestore';
import { blankToNull, isAllCampus } from './announcements';
import { EventDoc } from './types';

/**
 * How far back the upcoming query reaches so an event that has started but
 * not finished still lists as upcoming. Mirrors `_inProgressLookback` in
 * `app/lib/features/calendar/data/event_repository.dart`, so the API and the
 * app's Firestore stream agree and the list does not jump when one replaces
 * the other.
 */
export const IN_PROGRESS_LOOKBACK_MS = 2 * 24 * 60 * 60 * 1000;

/** An `events` document as read from Firestore. */
export interface EventRecord {
  id: string;
  data: EventDoc;
}

export interface EventJson {
  id: string;
  title: string;
  description: string | null;
  /** Venue name. */
  location: string | null;
  /** Street address of the venue. */
  address: string | null;
  branch: string | null;
  imageUrl: string | null;
  isFeatured: boolean;
  startTime: string | null;
  endTime: string | null;
}

export function toEventJson({ id, data }: EventRecord): EventJson {
  return {
    id,
    title: data.title ?? '',
    description: blankToNull(data.description),
    location: blankToNull(data.location),
    address: blankToNull(data.address),
    branch: blankToNull(data.branch),
    imageUrl: blankToNull(data.imageUrl),
    isFeatured: data.isFeatured ?? false,
    startTime:
      data.startTime instanceof Timestamp ? data.startTime.toDate().toISOString() : null,
    endTime:
      data.endTime instanceof Timestamp ? data.endTime.toDate().toISOString() : null,
  };
}

/** The instant an event is over; one with no end is over when it starts. */
function effectiveEndMs(data: EventDoc): number {
  return (data.endTime instanceof Timestamp ? data.endTime : data.startTime).toMillis();
}

/**
 * The events a member at [branch] sees in one view, in display order
 * (upcoming: soonest first; past: most recent first), capped at [limit].
 *
 * Past-ness is decided by the effective END, exactly as the app does: an
 * event that has started but not finished stays upcoming. Hidden docs
 * (tombstones of deleted website events) are never returned.
 *
 * [branchDocs] hold the window's docs whose `branch` equals [branch];
 * [anyDocs] the window's docs of every campus, from which the all-campus ones
 * (null, blank OR absent `branch`) are picked in memory. An equality filter on
 * `branch == null` would miss docs with no `branch` key, which is how older
 * all-campus events are stored. With no [branch] every campus is returned.
 */
export function pickEvents(
  branch: string | undefined,
  branchDocs: EventRecord[],
  anyDocs: EventRecord[],
  past: boolean,
  limit: number,
  nowMs: number,
): EventJson[] {
  const inView = (r: EventRecord) =>
    r.data.hidden !== true &&
    r.data.startTime instanceof Timestamp &&
    (effectiveEndMs(r.data) < nowMs) === past;

  const candidates = branch
    ? [...branchDocs, ...anyDocs.filter((r) => isAllCampus(r.data))]
    : anyDocs;

  const unique = new Map<string, EventRecord>();
  for (const r of candidates) if (inView(r)) unique.set(r.id, r);

  return [...unique.values()]
    .sort((a, b) => {
      const delta = a.data.startTime.toMillis() - b.data.startTime.toMillis();
      return past ? -delta : delta;
    })
    .slice(0, limit)
    .map(toEventJson);
}
