// One-off cleanup for the retired `syncSoundCloud` job (finding D7).
//
// That job keyed each sermon on `base64url(audioUrl).slice(0, 64)`, a prefix
// every SoundCloud stream URL shares, so all items collided into ONE `sermons`
// doc that was overwritten every hour with a hard-coded speaker. The job is
// gone; this deletes the docs it left behind (`source == 'soundcloud'`).
// The sermon library now comes from the yetanothersermon.host API.
//
// Dry run by default: prints what it would delete. Pass --apply to delete.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
//     node backend/functions/scripts/remove-soundcloud-sermons.mjs [--apply]
//   # or against the local emulator:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=<id> \
//     node backend/functions/scripts/remove-soundcloud-sermons.mjs --apply

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const apply = process.argv.includes('--apply');

const snap = await db.collection('sermons').where('source', '==', 'soundcloud').get();
for (const doc of snap.docs) {
  const { title, audioUrl } = doc.data();
  console.log(`${apply ? 'deleting' : 'would delete'} sermons/${doc.id}: ${title} (${audioUrl})`);
  if (apply) await doc.ref.delete();
}
console.log(`${snap.size} SoundCloud doc(s) ${apply ? 'deleted' : 'found; re-run with --apply to delete'}`);
