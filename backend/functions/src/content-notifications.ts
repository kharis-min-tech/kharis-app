import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import {
  DocumentData,
  FieldValue,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { branchTopic } from './topics';

/**
 * Content Studio -> device pushes, driven by Firestore document triggers.
 *
 * Announcements are pushed by `pushPendingAnnouncements` (a poller) in
 * `index.ts`; everything here covers the content a poller never watched —
 * events and branch venue details — and does it on the write itself, so an
 * admin saving in Content Studio reaches phones in seconds rather than at the
 * next scan.
 */

/**
 * Marker collection recording every push this module has sent.
 *
 * It is deliberately NOT the source document: writing a marker back onto
 * `events/{id}` would re-enter the very trigger that wrote it. A separate
 * collection makes a loop structurally impossible, and keying on the
 * CloudEvent id makes an at-least-once redelivery a no-op.
 */
const PUSH_LOG = 'pushLog';

/** Days a marker is kept — long enough to outlive every trigger retry. */
const PUSH_LOG_TTL_DAYS = 30;

/** FCM notification bodies are trimmed to this to stay readable on a lock screen. */
const MAX_BODY = 240;

const LONDON = 'Europe/London';

// Europe/London wall-clock formatters. `en-GB` gives `Sun, 12 Oct`; `en-US`
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

/**
 * Claims the exclusive right to send `key`, exactly once, ever.
 *
 * `create` fails when the marker already exists, which is the whole mechanism:
 * a redelivered CloudEvent loses the race and sends nothing. A claim that
 * fails for any other reason is logged and also treated as "do not send" —
 * duplicating a push to the whole church is worse than dropping one.
 */
async function claimPush(key: string): Promise<boolean> {
  try {
    await getFirestore()
      .collection(PUSH_LOG)
      .doc(key)
      .create({ claimedAt: FieldValue.serverTimestamp() });
    return true;
  } catch (e) {
    // gRPC ALREADY_EXISTS (6) is the expected redelivery case, not a failure.
    const code =
      e !== null && typeof e === 'object' && 'code' in e ? e.code : undefined;
    if (code !== 6 && code !== 'already-exists') {
      console.error(`[push] claim errored for ${key}:`, e);
    }
    return false;
  }
}

/**
 * Sends one topic push under a one-shot claim.
 *
 * On a send failure the claim is released, so the next retry or the next
 * meaningful edit can try again instead of being deduped forever against a
 * notification that never reached anyone.
 */
async function sendPush(
  key: string,
  topic: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  if (!(await claimPush(key))) return;
  const ref = getFirestore().collection(PUSH_LOG).doc(key);
  try {
    const messageId = await getMessaging().send({
      topic,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    await ref.set(
      { topic, title, body, messageId, sentAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    console.log(`[push] ${key} -> ${topic} (${messageId})`);
  } catch (e) {
    console.error(`[push] failed ${key} -> ${topic}:`, e);
    await ref.delete().catch(() => undefined);
  }
}

/** Equality that understands Firestore `Timestamp`, treating missing as null. */
function sameValue(a: unknown, b: unknown): boolean {
  if (a instanceof Timestamp && b instanceof Timestamp) return a.isEqual(b);
  return (a ?? null) === (b ?? null);
}

function cap(text: string, max: number): string {
  return text.length <= max ? text : `${text.slice(0, max - 1).trimEnd()}…`;
}

// ── Events ──────────────────────────────────────────────────────────────────

/**
 * Fields a member can see and plan around. A write that leaves all of these
 * untouched — an `isFeatured` toggle, a swapped banner image, a description
 * tweak — is not worth waking anybody's phone for.
 */
const EVENT_PUSH_FIELDS = [
  'title',
  'startTime',
  'endTime',
  'location',
  'branch',
] as const;

/** Field name -> the word a member understands, for the "what changed" line. */
const EVENT_CHANGE_LABEL: Record<string, string> = {
  title: 'name',
  startTime: 'time',
  endTime: 'time',
  location: 'venue',
  branch: 'campus',
};

/**
 * The when-and-where line the product owner asked for, e.g.
 * `Sun, 12 Oct · 2:00 PM – 4:00 PM · Kensington Town Hall, Hornton St`.
 *
 * A finish time on a later day is spelled out with its own date so an
 * overnight or multi-day event cannot read as ending before it starts.
 */
function eventWhenWhere(
  start: Date,
  end: Date | null,
  location: string,
): string {
  const startDay = londonDate.format(start);
  let time = londonTime.format(start);
  if (end) {
    const endDay = londonDate.format(end);
    time +=
      endDay === startDay
        ? ` – ${londonTime.format(end)}`
        : ` – ${endDay}, ${londonTime.format(end)}`;
  }
  return [startDay, time, location.trim()].filter((p) => p.length > 0).join(' · ');
}

/**
 * The push body for an event write: the when-and-where line on its own for a
 * brand-new event, led by what changed for an edit — `Time and venue changed
 * — Sun 11 Oct · 2:00 PM · Kensington Town Hall`. Two fields can map to the
 * same word (`startTime`/`endTime` are both "time"), so labels are deduped.
 */
function eventBody(changed: string[], whenWhere: string): string {
  if (changed.length === 0) return cap(whenWhere, MAX_BODY);
  const labels = [...new Set(changed.map((f) => EVENT_CHANGE_LABEL[f]))];
  const what =
    labels.length < 2
      ? labels[0]
      : `${labels.slice(0, -1).join(', ')} and ${labels[labels.length - 1]}`;
  return cap(
    `${what.charAt(0).toUpperCase()}${what.slice(1)} changed — ${whenWhere}`,
    MAX_BODY,
  );
}

/**
 * Pushes when an event is added, or when its name, time, venue or campus
 * changes on an event people may already have RSVP'd to.
 *
 * Silent for deletions (nowhere to route a tap), for events without a start
 * time, and for events already in the past — backfilling history must not
 * blast the congregation.
 */
export const onEventWritten = onDocumentWritten(
  { document: 'events/{eventId}', memory: '256MiB', timeoutSeconds: 60 },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const next = after.data() as DocumentData;

    const start = next.startTime;
    if (!(start instanceof Timestamp) || start.toMillis() <= Date.now()) return;

    const before = event.data?.before;
    const prev = before?.exists ? (before.data() as DocumentData) : null;
    const changed: string[] = prev
      ? EVENT_PUSH_FIELDS.filter((f) => !sameValue(prev[f], next[f]))
      : [];
    if (prev && changed.length === 0) return;

    const title = (next.title ?? '').toString().trim() || 'Kharis event';
    const location = (next.location ?? '').toString().trim();
    const end = next.endTime instanceof Timestamp ? next.endTime.toDate() : null;
    const whenWhere = eventWhenWhere(start.toDate(), end, location);

    const heading = prev ? `Event updated: ${title}` : `New event: ${title}`;
    const body = eventBody(changed, whenWhere);

    const payload: Record<string, string> = {
      type: 'event',
      eventId: event.params.eventId,
      branch: (next.branch ?? '').toString(),
      startTime: start.toDate().toISOString(),
      location,
    };

    const topic = branchTopic(next.branch);
    await sendPush(`${event.id}_${topic}`, topic, heading, body, payload);

    // A campus move also has to reach the members it moved AWAY from — they
    // are the ones who will otherwise turn up at the old venue. Distinct claim
    // key, and a body that leads with where the event went.
    const from = prev && changed.includes('branch') ? branchTopic(prev.branch) : topic;
    if (from === topic) return;
    const movedTo = (next.branch ?? '').toString().trim() || 'all campuses';
    await sendPush(
      `${event.id}_${from}`,
      from,
      heading,
      cap(`Moved to ${movedTo} — ${whenWhere}`, MAX_BODY),
      payload,
    );
  },
);

// ── Branch venue details ────────────────────────────────────────────────────

/** Venue fields a member reads off the home screen's campus card. */
const VENUE_FIELDS = ['address', 'meetingDays', 'meetingTime'] as const;

/**
 * Mirrors `formatServiceTime` in `app/lib/core/utils/service_time.dart`.
 *
 * The web portal's `<input type="time">` writes 24-hour `14:00` while the
 * Flutter admin and seed data write `2:00 PM`; both must read back the same.
 * Anything that is not a clock value is passed through untouched, so an admin
 * who typed `Sundays 10am & 6pm` keeps exactly what they typed.
 */
function serviceTime(raw: unknown): string {
  const value = (raw ?? '').toString().trim();
  const match = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(value);
  if (!match) return value;
  const hour = parseInt(match[1], 10);
  const minute = parseInt(match[2], 10);
  if (hour > 23 || minute > 59) return value;
  const hour12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${hour12}:${String(minute).padStart(2, '0')} ${hour < 12 ? 'AM' : 'PM'}`;
}

/**
 * Pushes when a branch's address or service schedule is edited.
 *
 * Creates are silent — a brand-new branch has no subscribers on its topic yet —
 * and so are deletions. Renames are silent too: the topic is keyed on the
 * branch NAME, so a renamed branch's members are still sitting on the old
 * topic and the new one would reach nobody.
 */
export const onBranchVenueWritten = onDocumentWritten(
  { document: 'branches/{branchId}', memory: '256MiB', timeoutSeconds: 60 },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists || !after?.exists) return;

    const prev = before.data() as DocumentData;
    const next = after.data() as DocumentData;
    if (VENUE_FIELDS.every((f) => sameValue(prev[f], next[f]))) return;

    const name = (next.name ?? '').toString().trim();
    if (!name) return;

    const schedule = [(next.meetingDays ?? '').toString().trim(), serviceTime(next.meetingTime)]
      .filter((p) => p.length > 0)
      .join(' · ');
    const address = (next.address ?? '').toString().trim();
    const detail = [schedule, address].filter((p) => p.length > 0).join(' · ');
    // The venue was cleared rather than changed — there is nothing to announce.
    if (!detail) return;

    const topic = branchTopic(name);
    await sendPush(
      `${event.id}_${topic}`,
      topic,
      `${name}: service details updated`,
      cap(`We now meet ${detail}`, MAX_BODY),
      {
        type: 'venue',
        branchId: event.params.branchId,
        branch: name,
        address,
        schedule,
      },
    );
  },
);

// ── Housekeeping ────────────────────────────────────────────────────────────

/**
 * Deletes push markers past their retention window.
 *
 * Markers exist only to dedupe trigger redeliveries, which happen within
 * minutes; without this they would accumulate one document per push forever.
 * Batched and bounded so a single run can never blow the timeout.
 */
export const purgePushLog = onSchedule(
  {
    schedule: 'every day 03:30',
    timeZone: LONDON,
    memory: '256MiB',
    timeoutSeconds: 300,
  },
  async () => {
    const db = getFirestore();
    const cutoff = Timestamp.fromMillis(
      Date.now() - PUSH_LOG_TTL_DAYS * 24 * 60 * 60 * 1000,
    );
    let deleted = 0;
    for (let pass = 0; pass < 10; pass++) {
      const snap = await db
        .collection(PUSH_LOG)
        .where('claimedAt', '<', cutoff)
        .limit(500)
        .get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      deleted += snap.size;
      if (snap.size < 500) break;
    }
    console.log(`[push] purged ${deleted} expired marker(s)`);
  },
);
