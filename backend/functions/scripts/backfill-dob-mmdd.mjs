// One-off backfill of `users/{uid}.dobMMDD` (`MM-DD`) from the string `dob`
// (`yyyy-mm-dd`), for profiles saved before the app started writing it.
// pushBirthdays queries `dobMMDD`, so a profile without it gets no birthday
// push until the member's next sign-in (the app backfills it on hydrate).
//
// Idempotent: only docs whose `dobMMDD` is missing or wrong are written.
// Paged by document id, so it reads the whole collection exactly once.
//
// Usage (either):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
//     node backend/functions/scripts/backfill-dob-mmdd.mjs
//   # or against the local emulator:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=<id> \
//     node backend/functions/scripts/backfill-dob-mmdd.mjs

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldPath } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const DOB = /^\d{4}-\d{2}-\d{2}$/;
const PAGE = 500;

let scanned = 0;
let updated = 0;
let last = null;
for (;;) {
  let query = db.collection('users').orderBy(FieldPath.documentId()).limit(PAGE);
  if (last) query = query.startAfter(last);
  const snap = await query.get();
  if (snap.empty) break;
  const batch = db.batch();
  let writes = 0;
  for (const doc of snap.docs) {
    const { dob, dobMMDD } = doc.data();
    if (typeof dob !== 'string' || !DOB.test(dob)) continue;
    const monthDay = dob.slice(5);
    if (dobMMDD === monthDay) continue;
    batch.update(doc.ref, { dobMMDD: monthDay });
    writes++;
  }
  if (writes > 0) await batch.commit();
  scanned += snap.size;
  updated += writes;
  last = snap.docs[snap.docs.length - 1];
}
console.log(`[backfill-dob-mmdd] scanned ${scanned}, updated ${updated}`);
