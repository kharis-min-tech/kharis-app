// Content Studio -> device pushes. The Studio writes Supabase only, so every
// sender here polls its tables over PostgREST (`content-studio.ts`) and keeps
// its claims, snapshots and checkpoints in `PushState` (`push-state.ts`).
// Pure: no Firebase imports; the scheduled wiring lives in
// content-notifications.ts.

import { createHash } from 'crypto';
import {
  APP_WORKSPACES,
  StudioRow,
  StudioService,
  fetchStudioBranches,
  fetchStudioRows,
  studioInstant,
  studioText,
} from './content-studio';
import { LONDON, londonClock, londonWallTime } from './london-time';
import { PushState } from './push-state';
import { dueService, REMINDER_RUN_EVERY_MS } from './service-reminders';
import { PREF_TOPIC, PushAudience, announcementAudience, branchTopic, prefAudience } from './topics';

/** One notification, ready for FCM. */
export interface PushMessage {
  audience: PushAudience;
  title: string;
  body: string;
  data: Record<string, string>;
}

/** Side effects of a poll, injected so tests need neither Firebase nor the network. */
export interface StudioPushDeps {
  fetchImpl: typeof fetch;
  state: PushState;
  /** Sends [message]; resolves to the FCM message id. */
  send(message: PushMessage): Promise<string>;
}

export type SendOutcome = 'sent' | 'already-claimed' | 'failed';

/** What one poll did. */
export interface PollResult {
  sent: number;
  failed: number;
}

const MINUTE_MS = 60_000;
const DAY_MS = 86_400_000;

/** FCM notification bodies are trimmed to this to stay readable on a lock screen. */
const MAX_BODY = 240;

function cap(text: string, max: number): string {
  return text.length <= max ? text : `${text.slice(0, max - 1).trimEnd()}…`;
}

const iso = (ms: number) => new Date(ms).toISOString();

/**
 * Sends [message] at most once under [key]. The claim comes BEFORE the send,
 * so overlapping runs cannot both send; a failed send releases it so the next
 * run retries. Recording the send has its own try: if it fails the claim
 * still stands, and nothing is sent twice.
 */
export async function sendOnce(
  deps: StudioPushDeps,
  key: string,
  message: PushMessage,
): Promise<SendOutcome> {
  if (!(await deps.state.claim(key))) return 'already-claimed';
  const target =
    'topic' in message.audience ? message.audience.topic : message.audience.condition;
  let messageId: string;
  try {
    messageId = await deps.send(message);
  } catch (e) {
    console.error(`[push] failed ${key} -> ${target}:`, e);
    await deps.state.release(key).catch(() => undefined);
    return 'failed';
  }
  try {
    await deps.state.recordSent(key, {
      target,
      title: message.title,
      body: message.body,
      messageId,
    });
  } catch (e) {
    console.error(`[push] ${key} sent, but recording it failed:`, e);
  }
  console.log(`[push] ${key} -> ${target} (${messageId})`);
  return 'sent';
}

function tally(outcomes: SendOutcome[]): PollResult {
  return {
    sent: outcomes.filter((o) => o === 'sent').length,
    failed: outcomes.filter((o) => o === 'failed').length,
  };
}

// Europe/London wall-clock formatters. `en-GB` gives `Sun 12 Oct`; `en-US`
// gives an uppercase `2:00 PM`, matching how service times are written
// everywhere else in the product.
const londonDate = new Intl.DateTimeFormat('en-GB', {
  timeZone: LONDON,
  weekday: 'short',
  day: 'numeric',
  month: 'short',
});
const londonTime = new Intl.DateTimeFormat('en-US', {
  timeZone: LONDON,
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

// ── Announcements ───────────────────────────────────────────────────────────

/** How far back the minute-by-minute announcement poll looks. */
export const ANNOUNCEMENT_WINDOW_MS = 15 * MINUTE_MS;

/**
 * Whether the app shows the `news` row [row] at [nowMs]: an app workspace,
 * an id and a title, not a draft (mirrors `NewsRepository.fromRow`),
 * published and not expired.
 */
function isLiveAnnouncement(row: StudioRow, nowMs: number): boolean {
  if (!APP_WORKSPACES.some((w) => w === row.workspace)) return false;
  if (studioText(row.id) === null || studioText(row.title) === null) return false;
  const status = studioText(row.status)?.toLowerCase();
  if (status && status !== 'published' && status !== 'live') return false;
  if (row.is_published === false || row.published === false) return false;
  const published = studioInstant(row.published_at);
  if (published === null || published > nowMs) return false;
  const expires = studioInstant(row.expires_at);
  return expires === null || expires > nowMs;
}

/**
 * Pushes Studio announcements (`news` rows in the app and general
 * workspaces) published within the last [ANNOUNCEMENT_WINDOW_MS]. A
 * Studio-scheduled notice is pushed when its `published_at` arrives, never
 * before. Each is claimed as `news_<id>`, so it goes out once; a failed send
 * is retried by the next run while the notice is still in the window.
 */
export async function runAnnouncementPush(
  deps: StudioPushDeps,
  nowMs: number,
): Promise<PollResult> {
  const rows = await fetchStudioRows(
    'news',
    {
      workspace: `in.(${APP_WORKSPACES.join(',')})`,
      published_at: [`gt.${iso(nowMs - ANNOUNCEMENT_WINDOW_MS)}`, `lte.${iso(nowMs)}`],
      order: 'published_at.desc',
      limit: '25',
    },
    deps.fetchImpl,
  );
  const outcomes: SendOutcome[] = [];
  for (const row of rows) {
    if (!isLiveAnnouncement(row, nowMs)) continue;
    if ((studioInstant(row.published_at) ?? 0) <= nowMs - ANNOUNCEMENT_WINDOW_MS) continue;
    const id = studioText(row.id) as string;
    const branch = studioText(row.branch_name) ?? '';
    const text = studioText(row.body) ?? '';
    const eventId = studioText(row.event_id);
    outcomes.push(
      await sendOnce(deps, `news_${id}`, {
        audience: announcementAudience(branch),
        title: studioText(row.title) as string,
        body: text.length > 140 ? `${text.slice(0, 137)}...` : text || 'New announcement',
        data: {
          type: 'announcement',
          newsId: id,
          branch,
          ...(eventId ? { eventId } : {}),
        },
      }),
    );
  }
  return tally(outcomes);
}

// ── Events ──────────────────────────────────────────────────────────────────

/** How often the event poll runs. */
export const EVENT_RUN_EVERY_MS = 5 * MINUTE_MS;

/**
 * How far before the last checkpoint each poll reaches back, so a row whose
 * `updated_at` (stamped at its transaction's start) commits just after a poll
 * is still seen. Re-seen rows match their snapshot and send nothing.
 */
const EVENT_OVERLAP_MS = 2 * MINUTE_MS;

const WEEKDAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/** What members plan around; the snapshot an update is compared with. */
interface EventFacts {
  title: string;
  /** The row's `start_time` / `end_time` (ms). */
  start: number;
  end: number | null;
  location: string;
  /** Branch name; '' for every branch. */
  branch: string;
  /** Weekly days, 0 = Sunday; empty for a one-off. */
  weeklyDays: number[];
  /** Last London date (`YYYY-MM-DD`) of a weekly event, or null. */
  until: string | null;
}

interface Occurrence {
  start: number;
  end: number | null;
}

function eventFacts(row: StudioRow): EventFacts | null {
  const title = studioText(row.title);
  const start = studioInstant(row.start_time);
  if (title === null || start === null) return null;
  const weekly = studioText(row.recurrence)?.toLowerCase() === 'weekly';
  const days = Array.isArray(row.recurrence_days) ? row.recurrence_days : [];
  const until = studioText(row.recurrence_until);
  return {
    title,
    start,
    end: studioInstant(row.end_time),
    location: studioText(row.location) ?? '',
    branch: studioText(row.branch_name) ?? '',
    weeklyDays: weekly
      ? [...new Set(days.filter((d): d is number => Number.isInteger(d) && d >= 0 && d <= 6))].sort()
      : [],
    // A bare date is a London calendar day; a timestamp is an instant.
    until:
      weekly && until !== null
        ? until.length <= 10
          ? until
          : londonClock(Date.parse(until)).dateKey
        : null,
  };
}

/**
 * The occurrence members would go to next, as the app dates it
 * (`EventRepository.fromRow`, in London time): a one-off until it ends; a
 * weekly event at its next (or running) occurrence on its days, at the first
 * occurrence's wall-clock time, until `recurrence_until`. Null once over.
 */
function nextOccurrence(facts: EventFacts, nowMs: number): Occurrence | null {
  const { start, end } = facts;
  if (facts.weeklyDays.length === 0) {
    return (end ?? start) > nowMs ? { start, end } : null;
  }
  const length = end === null ? null : end - start;
  const first = londonClock(start);
  const today = londonClock(nowMs);
  for (let offset = -1; offset < 8; offset++) {
    const at = londonWallTime(today.year, today.month, today.day + offset, first.hour, first.minute);
    const day = londonClock(at);
    if (day.dateKey < first.dateKey) continue;
    if (facts.until !== null && day.dateKey > facts.until) return null;
    if (!facts.weeklyDays.includes(day.weekday)) continue;
    const occurrenceEnd = length === null ? null : at + length;
    if ((occurrenceEnd ?? at) >= nowMs) return { start: at, end: occurrenceEnd };
  }
  return null;
}

/** The "what changed" words for an update; empty when nothing members plan around did. */
function eventChanges(prev: EventFacts, next: EventFacts): string[] {
  const changed: string[] = [];
  if (prev.title !== next.title) changed.push('name');
  if (
    prev.start !== next.start ||
    prev.end !== next.end ||
    prev.until !== next.until ||
    prev.weeklyDays.join() !== next.weeklyDays.join()
  ) {
    changed.push('time');
  }
  if (prev.location !== next.location) changed.push('venue');
  if (prev.branch !== next.branch) changed.push('branch');
  return changed;
}

/**
 * The when-and-where line, e.g.
 * `Sun 12 Oct · 2:00 PM – 4:00 PM · Kensington Town Hall, Hornton St`, or
 * `Every Sunday · 10:00 AM · …` for a weekly event. A finish on a later day
 * carries its own date so an overnight event cannot read as ending first.
 */
function eventWhenWhere(facts: EventFacts, at: Occurrence): string {
  const startDay = londonDate.format(at.start);
  let time = londonTime.format(at.start);
  if (at.end !== null) {
    const endDay = londonDate.format(at.end);
    time +=
      endDay === startDay
        ? ` – ${londonTime.format(at.end)}`
        : ` – ${endDay}, ${londonTime.format(at.end)}`;
  }
  const days = facts.weeklyDays.map((d) => WEEKDAY_NAMES[d]);
  const when =
    days.length === 0
      ? startDay
      : `Every ${days.length < 2 ? days[0] : `${days.slice(0, -1).join(', ')} and ${days[days.length - 1]}`}`;
  return [when, time, facts.location].filter((p) => p.length > 0).join(' · ');
}

/** The when-and-where line, led by what changed for an update. */
function eventBody(changed: string[], whenWhere: string): string {
  if (changed.length === 0) return cap(whenWhere, MAX_BODY);
  const what =
    changed.length < 2
      ? changed[0]
      : `${changed.slice(0, -1).join(', ')} and ${changed[changed.length - 1]}`;
  return cap(`${what.charAt(0).toUpperCase()}${what.slice(1)} changed: ${whenWhere}`, MAX_BODY);
}

/** How long an event's snapshot is kept: a month past its end, a year for an open weekly one. */
function snapshotKeepUntil(facts: EventFacts, at: Occurrence, nowMs: number): number {
  if (facts.weeklyDays.length === 0) return (at.end ?? at.start) + 30 * DAY_MS;
  if (facts.until !== null) return Date.parse(`${facts.until}T23:59:59Z`) + 30 * DAY_MS;
  return nowMs + 365 * DAY_MS;
}

/**
 * Pushes Studio events the app shows that were added or changed since the
 * last poll (checkpoint `events`):
 *
 * - a row created since the checkpoint: "New event: X";
 * - a row whose title, time (incl. weekly days and end date), place or branch
 *   differs from its last pushed snapshot (`event_<id>`): "Event updated: X".
 *   A branch move also tells the branch it left.
 *
 * Silent for saves that change nothing members plan around, for events that
 * are over (a weekly event: no upcoming occurrence), for rows hidden from the
 * app, and for an older event seen for the first time (nothing to compare
 * with: its snapshot is recorded instead). Sent only to devices with the
 * Events toggle on that follow the event's branch (every branch when none).
 * The checkpoint moves on only when every send succeeded, so a failed one is
 * retried by the next poll.
 */
export async function runEventPush(deps: StudioPushDeps, nowMs: number): Promise<PollResult> {
  const checkpoint = await deps.state.get<{ checkedAt: number }>('events');
  const from = (checkpoint?.checkedAt ?? nowMs - EVENT_RUN_EVERY_MS) - EVENT_OVERLAP_MS;
  const rows = await fetchStudioRows(
    'events',
    {
      or: `(updated_at.gt.${iso(from)},created_at.gt.${iso(from)})`,
      order: 'updated_at.asc',
      limit: '200',
    },
    deps.fetchImpl,
  );

  const outcomes: SendOutcome[] = [];
  for (const row of rows) {
    const id = studioText(row.id);
    const facts = eventFacts(row);
    // Shown in the app: the Studio's "Show on" list names the app or General
    // (`EventRepository.shownInApp`); unpublishing empties the list.
    const shown =
      Array.isArray(row.sites) && row.sites.some((s) => APP_WORKSPACES.some((w) => w === s));
    if (id === null || facts === null || !shown) continue;
    const at = nextOccurrence(facts, nowMs);
    if (at === null) continue;

    const key = `event_${id}`;
    const prev = await deps.state.get<EventFacts>(key);
    const created = studioInstant(row.created_at) ?? 0;
    const keepUntil = snapshotKeepUntil(facts, at, nowMs);
    if (prev === null && created <= from) {
      await deps.state.save(key, facts, keepUntil);
      continue;
    }
    const changed = prev === null ? [] : eventChanges(prev, facts);
    if (prev !== null && changed.length === 0) continue;

    const title = prev === null ? `New event: ${facts.title}` : `Event updated: ${facts.title}`;
    const whenWhere = eventWhenWhere(facts, at);
    const data = {
      type: 'event',
      eventId: id,
      branch: facts.branch,
      startTime: iso(at.start),
      location: facts.location,
    };
    const version = studioInstant(row.updated_at) ?? created;
    const sends = [
      sendOnce(deps, `${key}_${version}_${branchTopic(facts.branch)}`, {
        audience: prefAudience(PREF_TOPIC.events, facts.branch),
        title,
        body: eventBody(changed, whenWhere),
        data,
      }),
    ];
    // A move also has to reach the members it moved AWAY from: they are the
    // ones who would otherwise turn up at the old branch.
    if (prev !== null && branchTopic(prev.branch) !== branchTopic(facts.branch)) {
      sends.push(
        sendOnce(deps, `${key}_${version}_${branchTopic(prev.branch)}`, {
          audience: prefAudience(PREF_TOPIC.events, prev.branch),
          title,
          body: cap(`Moved to ${facts.branch || 'all branches'}: ${whenWhere}`, MAX_BODY),
          data,
        }),
      );
    }
    const results = await Promise.all(sends);
    outcomes.push(...results);
    if (!results.includes('failed')) await deps.state.save(key, facts, keepUntil);
  }

  const result = tally(outcomes);
  if (result.failed === 0) await deps.state.save('events', { checkedAt: nowMs });
  return result;
}

// ── Branch service details ──────────────────────────────────────────────────

/** How often the branch poll runs. */
export const BRANCH_RUN_EVERY_MS = 5 * MINUTE_MS;

/**
 * Mirrors `formatServiceTime` in `app/lib/core/utils/service_time.dart`:
 * 24-hour `14:00` reads `2:00 PM`; anything else passes through.
 */
function serviceTime(raw: string | null): string {
  const value = raw ?? '';
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!match) return value;
  const hour = parseInt(match[1], 10);
  const minute = parseInt(match[2], 10);
  if (hour > 23 || minute > 59) return value;
  const hour12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${hour12}:${String(minute).padStart(2, '0')} ${hour < 12 ? 'AM' : 'PM'}`;
}

/** `Sundays 1:00 PM`. */
function serviceWhen(s: StudioService): string {
  const day = s.day ? (s.day.toLowerCase().endsWith('s') ? s.day : `${s.day}s`) : '';
  return [day, serviceTime(s.startTime)].filter((p) => p.length > 0).join(' ');
}

const shortHash = (text: string) => createHash('sha1').update(text).digest('hex').slice(0, 12);

/**
 * Pushes "<Branch>: service details updated" when a branch's services change
 * day, start time or venue (name or address), compared with the snapshot
 * saved under `branches` (branch uuid -> signature). The first run only
 * records the snapshot; so does a branch seen for the first time, and one
 * whose services were all removed (nothing to announce). Sent to devices with
 * the Service Reminders toggle on that follow the branch. A failed send
 * keeps the old signature, so the next poll retries.
 */
export async function runBranchUpdatePush(deps: StudioPushDeps): Promise<PollResult> {
  const branches = await fetchStudioBranches(deps.fetchImpl);
  const saved = await deps.state.get<Record<string, string>>('branches');
  const next: Record<string, string> = {};
  const outcomes: SendOutcome[] = [];
  for (const branch of branches) {
    // What a member sees of the services: day, time, venue name and address.
    const signature = JSON.stringify(
      branch.services.map((s) => [s.day, s.startTime, s.venueName, s.venueAddress]),
    );
    const prev = saved?.[branch.uuid];
    next[branch.uuid] = signature;
    if (prev === undefined || prev === signature || branch.services.length === 0) continue;

    const schedule = branch.services.map(serviceWhen).join(', ');
    const detail = branch.services
      .map((s) =>
        [serviceWhen(s), s.venueAddress || s.venueName || ''].filter((p) => p.length > 0).join(' · '),
      )
      .join('; ');
    const outcome = await sendOnce(
      deps,
      `branch_${branch.uuid}_${shortHash(prev)}_${shortHash(signature)}`,
      {
        audience: prefAudience(PREF_TOPIC.serviceReminders, branch.name),
        title: `${branch.name}: service details updated`,
        body: cap(`We now meet ${detail}`, MAX_BODY),
        data: {
          type: 'venue',
          branchId: branch.slug,
          branch: branch.name,
          address: branch.services[0].venueAddress,
          schedule,
        },
      },
    );
    outcomes.push(outcome);
    if (outcome === 'failed') next[branch.uuid] = prev;
  }
  await deps.state.save('branches', next);
  return tally(outcomes);
}

// ── Service reminders ───────────────────────────────────────────────────────

/**
 * Reminds each branch an hour before each of its Studio services
 * (`service-reminders.ts` for the London-time arithmetic). Runs every
 * [REMINDER_RUN_EVERY_MS]; [nowMs] is snapped to that step so scheduler
 * jitter cannot open a gap or overlap between two windows. The claim is
 * branch + London date + start time, so a retried run never reminds twice. A
 * service without a readable day or time gets no reminder.
 */
export async function runServiceReminderPush(
  deps: StudioPushDeps,
  nowMs: number,
): Promise<PollResult> {
  const now = Math.floor(nowMs / REMINDER_RUN_EVERY_MS) * REMINDER_RUN_EVERY_MS;
  const branches = await fetchStudioBranches(deps.fetchImpl);
  const outcomes: SendOutcome[] = [];
  for (const branch of branches) {
    for (const service of branch.services) {
      const due = dueService(service.day, service.startTime, now);
      if (!due) continue;
      const address = service.venueAddress;
      outcomes.push(
        await sendOnce(deps, `service_${branch.slug}_${due.dateKey}_${service.startTime}`, {
          audience: prefAudience(PREF_TOPIC.serviceReminders, branch.name),
          title: `${branch.name}: service at ${londonTime.format(due.startMs)}`,
          body: cap(
            address
              ? `Starting in an hour at ${address}. See you there.`
              : 'Starting in an hour. See you there.',
            MAX_BODY,
          ),
          data: {
            type: 'service_reminder',
            branchId: branch.slug,
            branch: branch.name,
            startTime: iso(due.startMs),
            address,
          },
        }),
      );
    }
  }
  return tally(outcomes);
}
