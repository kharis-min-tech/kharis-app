// The Kharis Content Studio (Supabase), read over PostgREST exactly as the app
// reads it (`ContentApi` in app/lib/core/services/content_api.dart). Pure: no
// Firebase imports, so every poller built on it is testable with a mock fetch.

/** Content Studio Supabase project, read over PostgREST. */
export const CONTENT_STUDIO_URL = 'https://cqgyiqxhpxwasogpdghx.supabase.co';

/**
 * Supabase publishable (anon) key. Public by design: it ships in the app
 * (`ApiConfig.supabasePublishableKey`) and in the Studio's web bundle, and
 * row-level security only grants reads of published content.
 */
export const CONTENT_STUDIO_KEY = 'sb_publishable_fT5_NGYsk0Uh4IO_uYfXvg_ZhR8bl7K';

/**
 * Studio workspaces (`news.workspace`, `events.sites`) the app shows, most
 * specific first: "Mobile App", then the shared General workspace. `kharis`
 * and `kp2` are the websites'.
 */
export const APP_WORKSPACES = ['app', 'general'] as const;

/** How long a lookup waits for the Studio before giving up. */
const LOOKUP_TIMEOUT_MS = 15_000;

/** One Studio row. */
export type StudioRow = Record<string, unknown>;

/**
 * The PostgREST URL for [table] with [params]. A param given as an array is
 * repeated (`published_at=gt.X&published_at=lte.Y` is an AND).
 */
export function studioQueryUrl(
  table: string,
  params: Record<string, string | string[]>,
): string {
  const url = new URL(`${CONTENT_STUDIO_URL}/rest/v1/${table}`);
  url.searchParams.set('select', '*');
  for (const [key, value] of Object.entries(params)) {
    for (const v of Array.isArray(value) ? value : [value]) url.searchParams.append(key, v);
  }
  return url.toString();
}

/**
 * [table]'s rows matching [params]. Throws on a failed request, an error
 * status (PostgREST answers 404 while a table does not exist) or a non-array
 * body: a poller that cannot read the Studio must not mistake that for
 * "nothing changed".
 */
export async function fetchStudioRows(
  table: string,
  params: Record<string, string | string[]>,
  fetchImpl: typeof fetch = fetch,
): Promise<StudioRow[]> {
  let res: Response;
  try {
    res = await fetchImpl(studioQueryUrl(table, params), {
      headers: {
        apikey: CONTENT_STUDIO_KEY,
        Authorization: `Bearer ${CONTENT_STUDIO_KEY}`,
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    });
  } catch (e) {
    throw new Error(`Content Studio lookup failed: ${String(e)}`);
  }
  if (!res.ok) throw new Error(`Content Studio answered ${res.status}`);
  const rows: unknown = await res.json();
  if (!Array.isArray(rows)) throw new Error('Content Studio answered a non-array body');
  return rows.filter((r): r is StudioRow => r !== null && typeof r === 'object');
}

/** Trimmed text, or null for a non-string or blank value. */
export function studioText(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

/** An ISO timestamp column as epoch ms, or null. */
export function studioInstant(value: unknown): number | null {
  const text = studioText(value);
  if (text === null) return null;
  const ms = Date.parse(text);
  return Number.isNaN(ms) ? null : ms;
}

// ── Branches, services and venues ───────────────────────────────────────────

/** One weekly service, as the app's `CampusService` reads it. */
export interface StudioService {
  /** Weekday name as written in the Studio, e.g. `Sunday`. */
  day: string | null;
  /** 24-hour `HH:MM` (Postgres `time` without seconds), or the raw text. */
  startTime: string | null;
  venueName: string | null;
  /** Address lines joined like the app's `CampusVenue.address`. */
  venueAddress: string;
}

/** One active branch with its active services, in the app's service order. */
export interface StudioBranch {
  /** Supabase uuid: stable across renames. */
  uuid: string;
  /** Studio slug (`london`, `kp2-barking`): the app's `Branch.id`. */
  slug: string;
  /** Display name: the source of the FCM branch topic. */
  name: string;
  services: StudioService[];
}

const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

/** Mirrors `weekdayIndex` in branch_repository.dart: 0 = Sunday, null if unknown. */
function weekdayIndex(day: string | null): number | null {
  const d = day?.trim().toLowerCase() ?? '';
  if (d.length < 3) return null;
  const i = WEEKDAYS.findIndex((w) => w.startsWith(d.slice(0, 3)));
  return i < 0 ? null : i;
}

/** Postgres `time` (`14:00:00`) as `14:00`; anything else passes through. */
function clock(value: unknown): string | null {
  const t = studioText(value);
  if (t === null) return null;
  const m = /^(\d{2}:\d{2}):\d{2}(\.\d+)?$/.exec(t);
  return m ? m[1] : t;
}

/** Mirrors `CampusVenue.address`: lines joined, a repeated part shown once. */
function venueAddress(v: StudioRow): string {
  const seen = new Set<string>();
  const parts: string[] = [];
  for (const line of [v.address_line1, v.address_line2, v.city, v.postcode]) {
    const text = studioText(line);
    if (text === null) continue;
    for (const raw of text.split(',')) {
      const part = raw.trim().replace(/\s+/g, ' ');
      if (part && !seen.has(part.toLowerCase())) {
        seen.add(part.toLowerCase());
        parts.push(part);
      }
    }
  }
  return parts.join(', ');
}

/**
 * Joins Studio rows into branches the way the app's
 * `BranchRepository.joinBranches` does: active branches with a uuid and a
 * name, each with its active services ordered by `sort_order`, weekday, then
 * start time.
 */
export function joinStudioBranches(
  branches: StudioRow[],
  services: StudioRow[],
  venues: StudioRow[],
): StudioBranch[] {
  const venueById = new Map<string, StudioRow>();
  for (const v of venues) {
    const id = studioText(v.id);
    if (id !== null) venueById.set(id, v);
  }
  const servicesByBranch = new Map<string, StudioRow[]>();
  for (const s of services) {
    const branchId = studioText(s.branch_id);
    if (branchId === null || studioText(s.id) === null || studioText(s.name) === null) continue;
    if (s.is_active === false) continue;
    servicesByBranch.set(branchId, [...(servicesByBranch.get(branchId) ?? []), s]);
  }
  const result: StudioBranch[] = [];
  for (const b of branches) {
    if (b.is_active !== true) continue;
    const uuid = studioText(b.id);
    const name = studioText(b.name);
    if (uuid === null || name === null) continue;
    const rows = [...(servicesByBranch.get(uuid) ?? [])].sort(
      (x, y) =>
        (Number(x.sort_order) || 0) - (Number(y.sort_order) || 0) ||
        (weekdayIndex(studioText(x.day)) ?? 7) - (weekdayIndex(studioText(y.day)) ?? 7) ||
        (clock(x.start_time) ?? '').localeCompare(clock(y.start_time) ?? ''),
    );
    result.push({
      uuid,
      slug: studioText(b.slug) ?? uuid,
      name,
      services: rows.map((s) => {
        const venue = venueById.get(studioText(s.venue_id) ?? '');
        return {
          day: studioText(s.day),
          startTime: clock(s.start_time),
          venueName: venue ? studioText(venue.name) : null,
          venueAddress: venue ? venueAddress(venue) : '',
        };
      }),
    });
  }
  return result;
}

/** Active branches with their services and venues, read like the app does. */
export async function fetchStudioBranches(
  fetchImpl: typeof fetch = fetch,
): Promise<StudioBranch[]> {
  const [branches, services, venues] = await Promise.all([
    fetchStudioRows('branches', { is_active: 'eq.true' }, fetchImpl),
    fetchStudioRows('services', { is_active: 'eq.true' }, fetchImpl),
    fetchStudioRows('venues', {}, fetchImpl),
  ]);
  return joinStudioBranches(branches, services, venues);
}
