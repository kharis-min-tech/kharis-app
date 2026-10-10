import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { DocumentData, FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { TopicMessage, getMessaging } from 'firebase-admin/messaging';
import { branchTopic } from './topics';

/**
 * Studio notifications: pushes an admin composes in Content Studio (web or
 * in-app) and stores as `notifications/{id}`.
 *
 * The client only ever writes `draft`, `scheduled` or `cancelled` (see the
 * `notifications` block in `firestore.rules`). This module moves a due
 * `scheduled` doc through `sending` to `sent` or `failed`:
 *   - `onNotificationWritten` handles "Send now" (sendAt = server time) on the
 *     write itself;
 *   - `sendDueNotifications` picks up future-dated ones every 5 minutes.
 * Both go through [deliverNotification], whose transactional claim makes a
 * redelivered trigger or an overlapping scheduler run a no-op.
 */

const COLLECTION = 'notifications';
const LONDON = 'Europe/London';

/** Topic the app subscribes Studio users to (`KharisTopics.studioTest`). */
export const STUDIO_TEST_TOPIC = 'studio_test';

export const TITLE_MAX = 65;
export const BODY_MAX = 240;
export const LINK_MAX = 500;

/**
 * How far ahead of this instance's clock a `sendAt` may be and still count as
 * due. "Send now" stamps `sendAt` with the commit time, which can read a
 * moment ahead of the function's clock; without this the push would wait for
 * the next scheduler run.
 */
export const CLOCK_SKEW_MS = 30_000;

export type NotificationAudience =
  | { type: 'all' }
  | { type: 'branch'; branch: string }
  | { type: 'test' };

/** A validated Studio notification, ready to send. */
export interface StudioNotification {
  title: string;
  body: string;
  link: string | null;
  audience: NotificationAudience;
}

export type Validation =
  | { ok: true; value: StudioNotification }
  | { ok: false; error: string };

/** Reads `audience` from a stored doc; null when it is not one of the three shapes. */
export function parseAudience(raw: unknown): NotificationAudience | null {
  if (raw === null || typeof raw !== 'object') return null;
  const value = raw as Record<string, unknown>;
  switch (value.type) {
    case 'all':
      return { type: 'all' };
    case 'test':
      return { type: 'test' };
    case 'branch': {
      const branch = typeof value.branch === 'string' ? value.branch.trim() : '';
      return branch ? { type: 'branch', branch } : null;
    }
    default:
      return null;
  }
}

/** The FCM topic an audience is delivered on. */
export function audienceTopic(audience: NotificationAudience): string {
  switch (audience.type) {
    case 'all':
      return 'all';
    case 'branch':
      return branchTopic(audience.branch);
    case 'test':
      return STUDIO_TEST_TOPIC;
  }
}

/**
 * Whether [link] is something the app can open: an in-app path (`/m/<id>`,
 * `/giving`, ...) or an http(s) URL. A protocol-relative `//host` is refused,
 * it would read as a path to the router.
 */
export function isValidLink(link: string): boolean {
  if (link.length === 0 || link.length > LINK_MAX || /\s/.test(link)) return false;
  if (link.startsWith('/')) return !link.startsWith('//');
  try {
    const url = new URL(link);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

/**
 * Server-side re-check of what the rules already enforce. The Admin SDK and
 * the console bypass rules, and a malformed doc must fail loudly in Studio
 * history rather than reach every phone.
 */
export function validateNotification(data: DocumentData): Validation {
  const title = typeof data.title === 'string' ? data.title.trim() : '';
  if (!title) return { ok: false, error: 'Title is missing' };
  if (title.length > TITLE_MAX) return { ok: false, error: `Title is over ${TITLE_MAX} characters` };
  const body = typeof data.body === 'string' ? data.body.trim() : '';
  if (!body) return { ok: false, error: 'Message is missing' };
  if (body.length > BODY_MAX) return { ok: false, error: `Message is over ${BODY_MAX} characters` };
  let link: string | null = null;
  if (data.link !== undefined && data.link !== null && data.link !== '') {
    if (typeof data.link !== 'string' || !isValidLink(data.link.trim())) {
      return { ok: false, error: 'Link is not an app path or web address' };
    }
    link = data.link.trim();
  }
  const audience = parseAudience(data.audience);
  if (!audience) return { ok: false, error: 'Audience is not Everyone, a branch or Test' };
  return { ok: true, value: { title, body, link, audience } };
}

/** The FCM message for a validated notification. */
export function buildMessage(id: string, n: StudioNotification): TopicMessage {
  const data: Record<string, string> = { type: 'studio', notificationId: id };
  if (n.link) data.link = n.link;
  return {
    topic: audienceTopic(n.audience),
    notification: { title: n.title, body: n.body },
    data,
    // Same delivery settings as every other Kharis push (content-notifications.ts).
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

/** A doc is due when it is `scheduled` and its `sendAt` has arrived. */
export function isDue(data: DocumentData | undefined, nowMs: number): boolean {
  if (!data || data.status !== 'scheduled') return false;
  return data.sendAt instanceof Timestamp && data.sendAt.toMillis() <= nowMs + CLOCK_SKEW_MS;
}

/** What a claim decided for one doc. */
export type ClaimDecision =
  | { action: 'skip' }
  | { action: 'reject'; error: string }
  | { action: 'send'; notification: StudioNotification };

/** The claim decision for a doc as read inside the transaction. */
export function claimDecision(data: DocumentData | undefined, nowMs: number): ClaimDecision {
  if (!isDue(data, nowMs)) return { action: 'skip' };
  const parsed = validateNotification(data as DocumentData);
  return parsed.ok
    ? { action: 'send', notification: parsed.value }
    : { action: 'reject', error: parsed.error };
}

/**
 * Sends `notifications/{id}` once, if it is due.
 *
 * The transaction moves `scheduled` to `sending` before anything is sent, so
 * of two concurrent callers (a trigger redelivery, a scheduler run) only one
 * sees `scheduled`. A doc that fails validation is marked `failed` instead. A
 * send error is recorded as `failed` and is not retried: re-sending to the
 * whole church on a partial failure is worse than asking the admin to resend.
 */
export async function deliverNotification(id: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection(COLLECTION).doc(id);
  const decision = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const result = claimDecision(snap.exists ? snap.data() : undefined, Date.now());
    if (result.action === 'send') {
      tx.update(ref, { status: 'sending', updatedAt: FieldValue.serverTimestamp() });
    } else if (result.action === 'reject') {
      tx.update(ref, {
        status: 'failed',
        result: { error: result.error },
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return result;
  });
  if (decision.action === 'reject') {
    console.warn(`[studio-push] ${id} rejected: ${decision.error}`);
  }
  if (decision.action !== 'send') return;

  const message = buildMessage(id, decision.notification);
  try {
    const messageId = await getMessaging().send(message);
    await ref.update({
      status: 'sent',
      sentAt: FieldValue.serverTimestamp(),
      result: { messageId },
      updatedAt: FieldValue.serverTimestamp(),
    });
    console.log(`[studio-push] ${id} -> ${message.topic} (${messageId})`);
  } catch (e) {
    console.error(`[studio-push] ${id} -> ${message.topic} failed:`, e);
    await ref.update({
      status: 'failed',
      result: { error: (e instanceof Error ? e.message : String(e)).slice(0, 500) },
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

/**
 * "Send now": a `scheduled` doc whose `sendAt` has arrived is sent on the
 * write itself. This trigger also sees its own `sending`/`sent` writes; those
 * are not due, so it never loops.
 */
export const onNotificationWritten = onDocumentWritten(
  { document: `${COLLECTION}/{id}`, memory: '256MiB', timeoutSeconds: 60 },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists || !isDue(after.data(), Date.now())) return;
    await deliverNotification(event.params.id);
  },
);

/** Future-dated notifications: everything due, oldest first, every 5 minutes. */
export const sendDueNotifications = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: LONDON,
    memory: '256MiB',
    timeoutSeconds: 120,
  },
  async () => {
    const snap = await getFirestore()
      .collection(COLLECTION)
      .where('status', '==', 'scheduled')
      .where('sendAt', '<=', new Date(Date.now() + CLOCK_SKEW_MS))
      .orderBy('sendAt')
      .limit(100)
      .get();
    for (const doc of snap.docs) {
      await deliverNotification(doc.id);
    }
    console.log(`[studio-push] ${snap.size} due notification(s) checked`);
  },
);
