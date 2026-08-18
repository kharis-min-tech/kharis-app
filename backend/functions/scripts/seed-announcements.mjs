// Seeds the Firestore `news` collection so the app homepage has announcements
// to render: getAnnouncements reads `news`, the app's newsProvider calls it,
// and AnnouncementsCarousel on the home screen renders the result.
//
// Fields mirror NewsDoc (backend/functions/src/types.ts). `branch: null`
// means all-campus; `type` must be one of the app's NewsItem.types
// (Announcement | Ministry | Notice | Update — never Event). No `expiresAt`
// means the item never expires; admins retire it from the Content Studio.
//
// Idempotent: doc id fixed per announcement, written with { merge: true }.
//
// Usage (either):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
//     node backend/functions/scripts/seed-announcements.mjs
//   # or against the local emulator:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=kharis-church \
//     node backend/functions/scripts/seed-announcements.mjs

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

/** @type {Array<Record<string, unknown>>} */
const announcements = [
  {
    id: 'welcome-new-app',
    title: 'Welcome to the new Kharis app',
    body: 'Announcements from your campus now appear here — stay tuned.',
    type: 'Announcement',
    branch: null,
    imageUrl: null,
  },
  {
    id: 'messages-on-the-go',
    title: 'Listen to messages on the go',
    body: 'Every Sunday message is now available as audio and video in Messages.',
    type: 'Update',
    branch: null,
    imageUrl: null,
  },
  {
    id: 'london-hq-parking',
    title: 'London: use the Hornton Street car park',
    body: 'Kensington Town Hall parking is free on Sundays for the 10 AM service.',
    type: 'Notice',
    branch: 'london-hq',
    imageUrl: null,
  },
];

async function main() {
  console.log(`Seeding ${announcements.length} announcements…`);
  for (const a of announcements) {
    const { id, ...rest } = a;
    await db.collection('news').doc(id).set(
      {
        ...rest,
        publishedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    console.log(`  ✓ ${id}${rest.branch ? ` (${rest.branch})` : ' (all-campus)'}`);
  }
  console.log('Done. Verify: curl "https://us-central1-kharis-church.cloudfunctions.net/getAnnouncements?limit=20"');
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
