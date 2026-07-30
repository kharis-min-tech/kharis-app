// Seeds the Firestore `branches` collection with the real Kharis network
// (kharis.org) plus the Kharis Phase Two (KP2) young-adults branches.
//
// The app reads `branches` live from Firestore; the Dart seed in
// app/lib/.../branch_repository.dart is only an offline fallback. Run this once
// to populate the live project so the network + KP2 appear in the app.
//
// Idempotent: doc id = branch id, written with { merge: true }.
//
// Usage (either):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
//     node backend/functions/scripts/seed-branches.mjs
//   # or against the local emulator:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=<id> \
//     node backend/functions/scripts/seed-branches.mjs
//
// imageUrl uses bundled asset paths ('assets/design/city-<slug>.jpg') which the
// app renders directly; admins may later override with a hosted URL from the CMS.

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const gA = '#3B2A6B';
const gB = '#7C3AED';
const city = (slug) => `assets/design/city-${slug}.jpg`;

/** @type {Array<Record<string, unknown>>} */
const branches = [
  // ── Kharis main branches ──────────────────────────────────────────────────
  { id: 'london-hq', name: 'London', subtitle: 'United Kingdom · Main Campus', imageUrl: city('london-hq'), order: 0, group: 'Kharis', address: 'Kensington Town Hall, Hornton St, London W8 7NX', meetingDays: 'Sundays', meetingTime: '10:00 AM' },
  { id: 'birmingham', name: 'Birmingham', subtitle: 'United Kingdom', imageUrl: city('birmingham'), order: 1, group: 'Kharis' },
  { id: 'brighton', name: 'Brighton', subtitle: 'United Kingdom', imageUrl: city('brighton'), order: 2, group: 'Kharis' },
  { id: 'bristol', name: 'Bristol', subtitle: 'United Kingdom', imageUrl: city('bristol'), order: 3, group: 'Kharis' },
  { id: 'chatham', name: 'Chatham', subtitle: 'United Kingdom', imageUrl: city('chatham'), order: 4, group: 'Kharis' },
  { id: 'chelmsford', name: 'Chelmsford', subtitle: 'United Kingdom', imageUrl: city('chelmsford'), order: 5, group: 'Kharis' },
  { id: 'coventry', name: 'Coventry', subtitle: 'United Kingdom', imageUrl: city('coventry'), order: 6, group: 'Kharis' },
  { id: 'croydon', name: 'Croydon', subtitle: 'United Kingdom', imageUrl: city('croydon'), order: 7, group: 'Kharis' },
  { id: 'luton', name: 'Luton', subtitle: 'United Kingdom', imageUrl: city('luton'), order: 8, group: 'Kharis' },
  { id: 'manchester', name: 'Manchester', subtitle: 'United Kingdom', imageUrl: city('manchester'), order: 9, group: 'Kharis' },
  { id: 'northampton', name: 'Northampton', subtitle: 'United Kingdom', imageUrl: city('northampton'), order: 10, group: 'Kharis' },
  { id: 'nottingham', name: 'Nottingham', subtitle: 'United Kingdom', imageUrl: city('nottingham'), order: 11, group: 'Kharis' },
  { id: 'orpington', name: 'Orpington', subtitle: 'United Kingdom', imageUrl: city('orpington'), order: 12, group: 'Kharis' },
  { id: 'reading', name: 'Reading', subtitle: 'United Kingdom', imageUrl: city('reading'), order: 13, group: 'Kharis' },
  { id: 'accra', name: 'Accra', subtitle: 'Ghana', imageUrl: city('accra'), order: 14, group: 'Kharis' },
  { id: 'freetown', name: 'Freetown', subtitle: 'Sierra Leone', imageUrl: city('freetown'), order: 15, group: 'Kharis' },
  // ── Kharis Phase Two (KP2) — young-adults revival ───────────────────────────
  { id: 'kp2-london', name: 'KP2 London', subtitle: 'United Kingdom', imageUrl: city('kp2-london'), order: 20, group: 'KP2', address: 'Kensington Town Hall, Hornton St, London W8 7NX', meetingDays: 'Sundays', meetingTime: '2:00 PM' },
  { id: 'kp2-romford', name: 'KP2 Romford', subtitle: 'United Kingdom', imageUrl: city('kp2-romford'), order: 21, group: 'KP2', address: 'Marshalls Park Academy, Pettits Ln, Romford RM1 4EH', meetingDays: 'Sundays', meetingTime: '1:00 PM' },
  { id: 'kp2-peterborough', name: 'KP2 Peterborough', subtitle: 'United Kingdom', imageUrl: city('kp2-peterborough'), order: 22, group: 'KP2', address: 'Thomas Deacon Academy, Queens Gardens, Peterborough PE1 2UW', meetingDays: 'Sundays', meetingTime: '2:00 PM' },
  { id: 'kp2-birmingham', name: 'KP2 Birmingham', subtitle: 'United Kingdom', imageUrl: city('birmingham'), order: 23, group: 'KP2', address: 'Erdington Methodist Church, Erdington, Birmingham B23 6TX', meetingDays: 'Sundays', meetingTime: '1:00 PM' },
  { id: 'kp2-southampton', name: 'KP2 Southampton', subtitle: 'United Kingdom', imageUrl: city('kp2-southampton'), order: 24, group: 'KP2', address: 'River Church, 131A Northam Road, Southampton SO14 0HQ', meetingDays: 'Sundays', meetingTime: '2:00 PM' },
  { id: 'kp2-barking', name: 'KP2 Barking', subtitle: 'United Kingdom', imageUrl: city('kp2-barking'), order: 25, group: 'KP2', address: 'Greatfields School, Net St, Barking IG11 7QG', meetingDays: 'Sundays', meetingTime: '12:00 PM' },
];

async function main() {
  console.log(`Seeding ${branches.length} branches…`);
  let written = 0;
  for (const b of branches) {
    const { id, ...rest } = b;
    await db.collection('branches').doc(id).set(
      {
        gradientStart: gA,
        gradientEnd: gB,
        address: null,
        meetingDays: null,
        meetingTime: null,
        ...rest,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    written++;
    console.log(`  ✓ ${id} (${rest.group})`);
  }
  // Remove legacy placeholder docs replaced/dropped by the real network.
  for (const id of ['london', 'medway']) {
    await db.collection('branches').doc(id).delete();
    console.log(`  ✗ removed legacy ${id}`);
  }
  console.log(`Done — ${written} branches upserted.`);
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
