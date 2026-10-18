// Firestore security rules (backend/firestore.rules) against the Firestore
// emulator. Run with `npm run test:rules`, which starts the emulator through
// `firebase emulators:exec` (needs Java) and points FIRESTORE_EMULATOR_HOST
// at it; the plain `npm test` glob does not pick these up.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  RulesTestContext,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-kharis-rules';
const RULES_PATH = resolve(__dirname, '../../../../firestore.rules');

let env: RulesTestEnvironment;

/** Collections the app and Cloud Functions still read; no client writes. */
const PUBLIC_READ = ['branches', 'events', 'news', 'sermons', 'config', 'dailyContent', 'readingPlans'];

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(RULES_PATH, 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // Profiles left over from the retired in-app Studio keep their old roles;
    // the rules no longer grant them anything.
    await setDoc(doc(db, 'users/former'), { role: 'admin' });
    await setDoc(doc(db, 'users/campus'), {
      role: 'campus_admin',
      adminBranchIds: ['north'],
      adminBranchNames: ['North'],
    });
    await setDoc(doc(db, 'users/member'), { role: 'member', displayName: 'M' });
    for (const col of PUBLIC_READ) {
      await setDoc(doc(db, `${col}/north`), { title: 'n', branch: 'North' });
    }
    await setDoc(doc(db, 'notifications/n1'), {
      title: 't',
      body: 'b',
      status: 'sent',
      audience: { type: 'all' },
    });
  });
});

const formerAdmin = (): RulesTestContext => env.authenticatedContext('former');
const claimAdmin = (): RulesTestContext => env.authenticatedContext('claim', { admin: true });
const campusAdmin = (): RulesTestContext => env.authenticatedContext('campus');
const member = (): RulesTestContext => env.authenticatedContext('member');
const db = (ctx: RulesTestContext) => ctx.firestore();
const everyClient = () => [
  env.unauthenticatedContext(),
  member(),
  campusAdmin(),
  formerAdmin(),
  claimAdmin(),
];

describe('public content', () => {
  for (const col of PUBLIC_READ) {
    test(`${col}: anyone reads`, async () => {
      await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), `${col}/north`)));
      await assertSucceeds(getDocs(collection(db(member()), col)));
    });

    test(`${col}: no client creates, updates or deletes (admin roles included)`, async () => {
      for (const ctx of everyClient()) {
        const d = db(ctx);
        await assertFails(setDoc(doc(d, `${col}/new`), { title: 'x', branch: 'North' }));
        await assertFails(updateDoc(doc(d, `${col}/north`), { title: 'edited' }));
        await assertFails(deleteDoc(doc(d, `${col}/north`)));
      }
    });
  }
});

describe('users', () => {
  test('member edits their profile but never their role', async () => {
    const d = db(member());
    await assertSucceeds(updateDoc(doc(d, 'users/member'), { displayName: 'New name' }));
    await assertFails(updateDoc(doc(d, 'users/member'), { role: 'campus_admin' }));
    await assertFails(updateDoc(doc(d, 'users/member'), { role: 'admin' }));
  });

  test('a new profile starts with a plain role', async () => {
    const d = db(env.authenticatedContext('fresh'));
    await assertFails(setDoc(doc(d, 'users/fresh'), { role: 'campus_admin' }));
    await assertFails(setDoc(doc(d, 'users/fresh'), { role: 'admin' }));
    await assertSucceeds(setDoc(doc(d, 'users/fresh'), { role: 'member' }));
  });

  test('profiles are owner-only, whatever the role or claim', async () => {
    for (const ctx of [formerAdmin(), claimAdmin(), campusAdmin()]) {
      await assertFails(getDoc(doc(db(ctx), 'users/member')));
      await assertFails(updateDoc(doc(db(ctx), 'users/member'), { role: 'admin' }));
    }
    await assertFails(getDocs(collection(db(formerAdmin()), 'users')));
    await assertSucceeds(getDoc(doc(db(member()), 'users/member')));
  });

  test('every profile write the app makes is accepted', async () => {
    const fresh = env.authenticatedContext('fresh');
    const d = db(fresh);
    const ref = doc(d, 'users/fresh');
    // FirebaseAuthRepository.register / _hydrate / _upsertProfile create.
    await assertSucceeds(
      setDoc(
        ref,
        {
          email: 'a@b.co',
          displayName: 'Member',
          role: 'member',
          branch: null,
          photoUrl: null,
          createdAt: serverTimestamp(),
        },
        { merge: true },
      ),
    );
    // updateProfile.
    await assertSucceeds(
      setDoc(
        ref,
        {
          displayName: 'New',
          branch: 'North',
          photoUrl: 'https://x/y.png',
          phone: '+44 7000 000000',
          dob: '1990-10-18',
          dobMMDD: '10-18',
        },
        { merge: true },
      ),
    );
    // updateNotificationPrefs, branch_provider (explicit null), FCM token.
    await assertSucceeds(
      setDoc(ref, { notificationPrefs: { announcements: true, events: false } }, { merge: true }),
    );
    await assertSucceeds(setDoc(ref, { branch: null }, { merge: true }));
    await assertSucceeds(
      setDoc(ref, { fcmToken: 'tok', fcmTokenUpdatedAt: serverTimestamp() }, { merge: true }),
    );
    // Re-hydrate merge of the full shape (role unchanged).
    await assertSucceeds(
      setDoc(
        ref,
        {
          email: 'a@b.co',
          displayName: 'New',
          role: 'member',
          branch: null,
          photoUrl: null,
          createdAt: serverTimestamp(),
        },
        { merge: true },
      ),
    );
    // Anonymous guest create.
    await assertSucceeds(
      setDoc(doc(db(env.authenticatedContext('anon')), 'users/anon'), {
        email: '',
        displayName: 'Guest',
        role: 'guest',
        branch: null,
        photoUrl: null,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('profile keys are allowlisted and type-checked', async () => {
    const d = db(member());
    const ref = doc(d, 'users/member');
    await assertFails(updateDoc(ref, { isAdmin: true }));
    await assertFails(updateDoc(ref, { adminBranchIds: ['north'] }));
    await assertFails(updateDoc(ref, { dob: '18/10/1990', dobMMDD: '10/19' }));
    await assertFails(updateDoc(ref, { dob: 19901018 }));
    await assertFails(updateDoc(ref, { fcmToken: 'x'.repeat(4097) }));
    await assertFails(updateDoc(ref, { fcmToken: '' }));
    await assertFails(updateDoc(ref, { fcmToken: 42 }));
    await assertFails(updateDoc(ref, { displayName: 'x'.repeat(201) }));
    await assertFails(updateDoc(ref, { notificationPrefs: 'all' }));
    await assertFails(updateDoc(ref, { fcmTokenUpdatedAt: 'now' }));
    await assertSucceeds(updateDoc(ref, { fcmToken: 'x'.repeat(4096) }));
    // Creates are checked on every key.
    const fresh = db(env.authenticatedContext('fresh'));
    await assertFails(setDoc(doc(fresh, 'users/fresh'), { role: 'member', score: 1 }));
    await assertFails(setDoc(doc(fresh, 'users/fresh'), { role: 'member', fcmToken: 7 }));
  });

  test('dobMMDD must agree with dob', async () => {
    const ref = doc(db(member()), 'users/member');
    await assertFails(updateDoc(ref, { dob: '1990-10-18', dobMMDD: '01-01' }));
    await assertFails(updateDoc(ref, { dobMMDD: '10-18' })); // no dob to match
    await assertSucceeds(updateDoc(ref, { dob: '1990-10-18', dobMMDD: '10-18' }));
    await assertFails(updateDoc(ref, { dob: '1990-11-02' })); // stale dobMMDD
    await assertSucceeds(updateDoc(ref, { dob: '1990-11-02', dobMMDD: '11-02' }));
  });

  test('a legacy profile backfills dobMMDD and stays editable', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/legacy'), {
        role: 'member',
        dob: '1985-03-07',
        oldStudioField: 'kept',
      });
    });
    const ref = doc(db(env.authenticatedContext('legacy')), 'users/legacy');
    await assertSucceeds(setDoc(ref, { dobMMDD: '03-07' }, { merge: true }));
    await assertSucceeds(updateDoc(ref, { displayName: 'Still editable' }));
  });
});

describe('account deletion', () => {
  const NOW = Timestamp.now();

  /** The member's own data, plus another member's to prove isolation. */
  const seed = async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, 'users/other'), { role: 'member', displayName: 'O' });
      for (const uid of ['member', 'other']) {
        await setDoc(doc(d, `users/${uid}/notes/n1`), { body: 'note', updatedAt: NOW });
        await setDoc(doc(d, `users/${uid}/playlists/favorites`), {
          name: 'Favourites',
          sermonIds: ['s1'],
          createdAt: NOW,
          updatedAt: NOW,
        });
        await setDoc(doc(d, `rsvps/${uid}_e1`), { userId: uid, eventId: 'e1' });
      }
    });
  };

  test('owner can delete their own profile', async () => {
    await assertSucceeds(deleteDoc(doc(db(member()), 'users/member')));
  });

  test("a member cannot delete another member's profile", async () => {
    await seed();
    await assertFails(deleteDoc(doc(db(member()), 'users/other')));
    await assertFails(deleteDoc(doc(env.unauthenticatedContext().firestore(), 'users/member')));
  });

  test('a former admin role or the admin claim deletes no other profile', async () => {
    await assertFails(deleteDoc(doc(db(formerAdmin()), 'users/member')));
    await assertFails(deleteDoc(doc(db(claimAdmin()), 'users/member')));
  });

  test('owner deletes own notes, playlists and RSVPs but not anyone else’s', async () => {
    await seed();
    const d = db(member());
    await assertSucceeds(deleteDoc(doc(d, 'users/member/notes/n1')));
    await assertSucceeds(deleteDoc(doc(d, 'users/member/playlists/favorites')));
    await assertSucceeds(deleteDoc(doc(d, 'rsvps/member_e1')));
    await assertFails(deleteDoc(doc(d, 'users/other/notes/n1')));
    await assertFails(deleteDoc(doc(d, 'users/other/playlists/favorites')));
    await assertFails(deleteDoc(doc(d, 'rsvps/other_e1')));
    // Not even a former admin may touch a member's notes or playlists.
    await assertFails(deleteDoc(doc(db(formerAdmin()), 'users/other/notes/n1')));
    await assertFails(deleteDoc(doc(db(formerAdmin()), 'users/other/playlists/favorites')));
  });

  test('the in-app deletion sequence succeeds and leaves others intact', async () => {
    await seed();
    const d = db(member());
    // Same order as AccountDataRepository.deleteUserData.
    const notes = await assertSucceeds(getDocs(collection(d, 'users/member/notes')));
    const playlists = await assertSucceeds(getDocs(collection(d, 'users/member/playlists')));
    const rsvps = await assertSucceeds(
      getDocs(query(collection(d, 'rsvps'), where('userId', '==', 'member'))),
    );
    for (const snap of [...notes.docs, ...playlists.docs, ...rsvps.docs]) {
      await assertSucceeds(deleteDoc(snap.ref));
    }
    await assertSucceeds(deleteDoc(doc(d, 'users/member')));

    await env.withSecurityRulesDisabled(async (ctx) => {
      const admin = ctx.firestore();
      for (const path of [
        'users/member',
        'users/member/notes/n1',
        'users/member/playlists/favorites',
        'rsvps/member_e1',
      ]) {
        if ((await getDoc(doc(admin, path))).exists()) throw new Error(`${path} survived`);
      }
      for (const path of [
        'users/other',
        'users/other/notes/n1',
        'users/other/playlists/favorites',
        'rsvps/other_e1',
      ]) {
        if (!(await getDoc(doc(admin, path))).exists()) throw new Error(`${path} was removed`);
      }
    });
  });

  test('a deleted profile cannot be recreated without a role', async () => {
    await assertSucceeds(deleteDoc(doc(db(member()), 'users/member')));
    // e.g. a late FCM token merge from the deleted session.
    await assertFails(setDoc(doc(db(member()), 'users/member'), { fcmToken: 't' }, { merge: true }));
  });
});

describe('other collections', () => {
  test('motdSchedule is denied to everyone', async () => {
    for (const ctx of everyClient()) {
      await assertFails(getDoc(doc(db(ctx), 'motdSchedule/2026-10-04')));
      await assertFails(setDoc(doc(db(ctx), 'motdSchedule/2026-10-04'), { sermonId: 's', title: 't' }));
    }
  });

  test('retired Studio collections are closed: notifications, visitors, testimonies', async () => {
    for (const ctx of everyClient()) {
      const d = db(ctx);
      await assertFails(getDoc(doc(d, 'notifications/n1')));
      await assertFails(setDoc(doc(d, 'notifications/n2'), { title: 't', status: 'draft' }));
      await assertFails(getDoc(doc(d, 'visitors/v1')));
      await assertFails(setDoc(doc(d, 'visitors/v1'), { name: 'V', createdAt: Timestamp.now() }));
      await assertFails(getDoc(doc(d, 'testimonies/t1')));
      await assertFails(setDoc(doc(d, 'testimonies/t1'), { text: 'T', createdAt: Timestamp.now() }));
    }
  });

  test('feedback is one doc per member per UTC day; nobody reads it back', async () => {
    const d = db(member());
    const now = new Date();
    const day =
      `${now.getUTCFullYear()}` +
      `${String(now.getUTCMonth() + 1).padStart(2, '0')}` +
      `${String(now.getUTCDate()).padStart(2, '0')}`;
    const feedback = (rating: number) => ({
      uid: 'member',
      rating,
      comment: 'Great',
      source: 'settings',
      platform: 'ios',
      createdAt: serverTimestamp(),
    });
    const ref = doc(d, `app_feedback/member_${day}`);
    await assertSucceeds(setDoc(ref, feedback(5)));
    // A second submission the same day replaces the first.
    await assertSucceeds(setDoc(ref, feedback(4)));
    // Any other id is refused: auto ids, another day, another member's prefix.
    await assertFails(setDoc(doc(d, 'app_feedback/f1'), feedback(5)));
    await assertFails(setDoc(doc(d, 'app_feedback/member_19990101'), feedback(5)));
    await assertFails(setDoc(doc(d, `app_feedback/other_${day}`), feedback(5)));
    await assertFails(
      setDoc(doc(db(env.authenticatedContext('other')), `app_feedback/member_${day}`), {
        ...feedback(5),
        uid: 'other',
      }),
    );
    for (const ctx of [member(), formerAdmin(), claimAdmin()]) {
      await assertFails(getDoc(doc(db(ctx), `app_feedback/member_${day}`)));
    }
  });

  test('RSVPs: nobody lists or deletes another member\'s, admin roles included', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'rsvps/member_e1'), { userId: 'member', eventId: 'e1' });
    });
    for (const ctx of [formerAdmin(), claimAdmin()]) {
      await assertFails(getDocs(collection(db(ctx), 'rsvps')));
      await assertFails(getDoc(doc(db(ctx), 'rsvps/member_e1')));
      await assertFails(deleteDoc(doc(db(ctx), 'rsvps/member_e1')));
    }
    await assertSucceeds(getDoc(doc(db(member()), 'rsvps/member_e1')));
  });
});
