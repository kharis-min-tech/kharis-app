// Push bookkeeping: one-shot send claims, plus the snapshots and checkpoints
// the Content Studio pollers compare against. Every sender goes through the
// `PushState` interface, so this storage (Firestore today) can move to
// Supabase without touching them.
//
// Firestore layout:
// - `pushLog/{key}`: one claim per push, `{claimedAt, target, title, body,
//   messageId, sentAt}`. Purged 30 days after the claim.
// - `pushState/{key}`: a saved value, `{value, savedAt, keepUntil?}`. Purged
//   once `keepUntil` has passed; kept for good without one.

import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';

/** What a claimed push sent, recorded on its claim. */
export interface SentRecord {
  /** The FCM topic or condition. */
  target: string;
  title: string;
  body: string;
  messageId: string;
}

export interface PushState {
  /**
   * Claims the exclusive right to send [key], once. False when it is already
   * claimed, and also when the claim itself fails: duplicating a push to the
   * whole church is worse than dropping one.
   */
  claim(key: string): Promise<boolean>;
  /** Drops [key]'s claim after a failed send, so a later run can retry. */
  release(key: string): Promise<void>;
  recordSent(key: string, sent: SentRecord): Promise<void>;
  /** The value last saved under [key], or null. */
  get<T>(key: string): Promise<T | null>;
  /** Saves [value] under [key], kept until [keepUntilMs] (for good when omitted). */
  save(key: string, value: object, keepUntilMs?: number): Promise<void>;
}

const CLAIMS = 'pushLog';
const SAVED = 'pushState';

/** Days a claim is kept: long enough to outlive every retry and poll overlap. */
const CLAIM_TTL_DAYS = 30;

/** Firestore-backed [PushState]. */
export const pushState: PushState = {
  async claim(key) {
    try {
      await getFirestore()
        .collection(CLAIMS)
        .doc(key)
        .create({ claimedAt: FieldValue.serverTimestamp() });
      return true;
    } catch (e) {
      // gRPC ALREADY_EXISTS (6) is the expected repeat, not a failure.
      const code = e !== null && typeof e === 'object' && 'code' in e ? e.code : undefined;
      if (code !== 6 && code !== 'already-exists') {
        console.error(`[push] claim errored for ${key}:`, e);
      }
      return false;
    }
  },
  async release(key) {
    await getFirestore().collection(CLAIMS).doc(key).delete();
  },
  async recordSent(key, sent) {
    await getFirestore()
      .collection(CLAIMS)
      .doc(key)
      .set({ ...sent, sentAt: FieldValue.serverTimestamp() }, { merge: true });
  },
  async get<T>(key: string) {
    const snap = await getFirestore().collection(SAVED).doc(key).get();
    return snap.exists ? ((snap.get('value') as T | undefined) ?? null) : null;
  },
  async save(key, value, keepUntilMs) {
    await getFirestore()
      .collection(SAVED)
      .doc(key)
      .set({
        value,
        savedAt: FieldValue.serverTimestamp(),
        ...(keepUntilMs === undefined ? {} : { keepUntil: Timestamp.fromMillis(keepUntilMs) }),
      });
  },
};

/**
 * Deletes claims older than [CLAIM_TTL_DAYS] and saved values past their
 * `keepUntil`. Batched and bounded so one run can never blow its timeout.
 * Returns how many documents went.
 */
export async function purgePushState(nowMs: number): Promise<number> {
  const db = getFirestore();
  const queries = [
    db
      .collection(CLAIMS)
      .where('claimedAt', '<', Timestamp.fromMillis(nowMs - CLAIM_TTL_DAYS * 86_400_000)),
    db.collection(SAVED).where('keepUntil', '<', Timestamp.fromMillis(nowMs)),
  ];
  let deleted = 0;
  for (const query of queries) {
    for (let pass = 0; pass < 10; pass++) {
      const snap = await query.limit(500).get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      deleted += snap.size;
      if (snap.size < 500) break;
    }
  }
  return deleted;
}
