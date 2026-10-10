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
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-kharis-rules';
const RULES_PATH = resolve(__dirname, '../../../../firestore.rules');

let env: RulesTestEnvironment;

/** Branch docs as stored: keyed by id, news/events refer to them by name. */
const NORTH = { name: 'North', order: 1, group: 'UK', isActive: true, subtitle: 'N' };
const SOUTH = { name: 'South', order: 2, group: 'UK', isActive: true, subtitle: 'S' };

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
    await setDoc(doc(db, 'users/super'), { role: 'admin' });
    await setDoc(doc(db, 'users/campus'), {
      role: 'campus_admin',
      adminBranchIds: ['north'],
      adminBranchNames: ['North'],
    });
    await setDoc(doc(db, 'users/member'), { role: 'member', displayName: 'M' });
    await setDoc(doc(db, 'branches/north'), NORTH);
    await setDoc(doc(db, 'branches/south'), SOUTH);
    for (const col of ['news', 'events']) {
      await setDoc(doc(db, `${col}/north`), { title: 'n', branch: 'North' });
      await setDoc(doc(db, `${col}/south`), { title: 's', branch: 'South' });
      await setDoc(doc(db, `${col}/all`), { title: 'a', branch: null });
      await setDoc(doc(db, `${col}/legacy`), { title: 'l' });
    }
  });
});

const superAdmin = (): RulesTestContext => env.authenticatedContext('super');
const claimAdmin = (): RulesTestContext => env.authenticatedContext('claim', { admin: true });
const campusAdmin = (): RulesTestContext => env.authenticatedContext('campus');
const member = (): RulesTestContext => env.authenticatedContext('member');
const db = (ctx: RulesTestContext) => ctx.firestore();

describe('news and events', () => {
  for (const col of ['news', 'events']) {
    test(`${col}: campus admin creates, updates and deletes own-campus items`, async () => {
      const d = db(campusAdmin());
      await assertSucceeds(setDoc(doc(d, `${col}/new`), { title: 'x', branch: 'North' }));
      await assertSucceeds(updateDoc(doc(d, `${col}/north`), { title: 'edited' }));
      await assertSucceeds(deleteDoc(doc(d, `${col}/north`)));
    });

    test(`${col}: campus admin cannot create for another campus or all-campus`, async () => {
      const d = db(campusAdmin());
      await assertFails(setDoc(doc(d, `${col}/x1`), { title: 'x', branch: 'South' }));
      await assertFails(setDoc(doc(d, `${col}/x2`), { title: 'x', branch: null }));
      await assertFails(setDoc(doc(d, `${col}/x3`), { title: 'x' }));
      await assertFails(setDoc(doc(d, `${col}/x4`), { title: 'x', branch: '  ' }));
    });

    test(`${col}: campus admin cannot update or delete another campus or all-campus`, async () => {
      const d = db(campusAdmin());
      for (const id of ['south', 'all', 'legacy']) {
        await assertFails(updateDoc(doc(d, `${col}/${id}`), { title: 'edited' }));
        await assertFails(updateDoc(doc(d, `${col}/${id}`), { branch: 'North' }));
        await assertFails(deleteDoc(doc(d, `${col}/${id}`)));
      }
    });

    test(`${col}: campus admin cannot move an own-campus item off their campus`, async () => {
      const d = db(campusAdmin());
      await assertFails(updateDoc(doc(d, `${col}/north`), { branch: 'South' }));
      await assertFails(updateDoc(doc(d, `${col}/north`), { branch: null }));
    });

    test(`${col}: super admin (role or claim) writes any campus; members cannot`, async () => {
      await assertSucceeds(setDoc(doc(db(superAdmin()), `${col}/a1`), { title: 'x', branch: null }));
      await assertSucceeds(updateDoc(doc(db(superAdmin()), `${col}/north`), { branch: 'South' }));
      await assertSucceeds(deleteDoc(doc(db(claimAdmin()), `${col}/all`)));
      await assertFails(setDoc(doc(db(member()), `${col}/m1`), { title: 'x', branch: 'North' }));
      await assertFails(deleteDoc(doc(db(member()), `${col}/north`)));
    });
  }

  test('news shape checks still apply to campus admins', async () => {
    const d = db(campusAdmin());
    await assertFails(
      setDoc(doc(d, 'news/bad'), { title: 'x', branch: 'North', linkUrl: 'javascript:alert(1)' }),
    );
    await assertSucceeds(
      setDoc(doc(d, 'news/good'), { title: 'x', branch: 'North', linkUrl: 'https://kharis.org' }),
    );
    await assertFails(setDoc(doc(d, 'events/bad'), { title: 'x', branch: 'North', address: 'a'.repeat(301) }));
  });

  test('a campus admin without campus lists manages nothing', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/campus'), { role: 'campus_admin' });
    });
    await assertFails(setDoc(doc(db(campusAdmin()), 'news/x'), { title: 'x', branch: 'North' }));
    await assertFails(updateDoc(doc(db(campusAdmin()), 'branches/north'), { subtitle: 'x' }));
  });
});

describe('branches', () => {
  test('campus admin updates own branch giving, home, contact and services', async () => {
    const d = db(campusAdmin());
    await assertSucceeds(
      updateDoc(doc(d, 'branches/north'), {
        giving: { url: 'https://give.example/north', bankName: 'Bank', sortCode: '00-00-00' },
        home: { sections: [{ id: 'reading', enabled: true }, { id: 'giving', enabled: true }] },
        contact: { email: 'north@kharis.org', phone: '0100' },
        services: [{ id: 's1', name: 'Sunday', day: 'Sunday', startTime: '10:00' }],
        venues: [{ id: 'v1', name: 'Hall' }],
        instagram: 'kharis_north',
      }),
    );
    // A full-document set that keeps identity fields unchanged is fine too.
    await assertSucceeds(setDoc(doc(d, 'branches/north'), { ...NORTH, subtitle: 'new' }));
  });

  test('campus admin cannot change own branch name, order, group or isActive', async () => {
    const d = db(campusAdmin());
    const changes: Record<string, unknown>[] = [
      { name: 'Renamed' },
      { order: 9 },
      { group: 'Elsewhere' },
      { isActive: false },
    ];
    for (const change of changes) {
      await assertFails(updateDoc(doc(d, 'branches/north'), change));
    }
    // Dropping an identity field is a change too.
    const { isActive: _dropped, ...withoutActive } = NORTH;
    void _dropped;
    await assertFails(setDoc(doc(d, 'branches/north'), withoutActive));
  });

  test('campus admin cannot update another branch, nor create or delete branches', async () => {
    const d = db(campusAdmin());
    await assertFails(updateDoc(doc(d, 'branches/south'), { subtitle: 'x' }));
    await assertFails(setDoc(doc(d, 'branches/east'), { name: 'East', order: 3 }));
    await assertFails(deleteDoc(doc(d, 'branches/north')));
  });

  test('giving and home are shape-checked for every writer', async () => {
    for (const ctx of [campusAdmin(), superAdmin()]) {
      const d = db(ctx);
      await assertFails(updateDoc(doc(d, 'branches/north'), { giving: { url: 'ftp://x' } }));
      await assertFails(updateDoc(doc(d, 'branches/north'), { giving: 'https://x' }));
      await assertFails(updateDoc(doc(d, 'branches/north'), { home: { sections: 'reading' } }));
      await assertFails(updateDoc(doc(d, 'branches/north'), { home: [] }));
      await assertSucceeds(updateDoc(doc(d, 'branches/north'), { giving: null, home: null }));
    }
  });

  test('super admin manages every branch field', async () => {
    const d = db(superAdmin());
    await assertSucceeds(updateDoc(doc(d, 'branches/south'), { name: 'South Bank', isActive: false }));
    await assertSucceeds(setDoc(doc(d, 'branches/east'), { name: 'East', order: 3 }));
    await assertSucceeds(deleteDoc(doc(d, 'branches/east')));
    await assertFails(updateDoc(doc(db(member()), 'branches/north'), { subtitle: 'x' }));
  });
});

describe('config', () => {
  test('campus admins and members cannot write config/*', async () => {
    for (const ctx of [campusAdmin(), member()]) {
      const d = db(ctx);
      await assertFails(setDoc(doc(d, 'config/featured'), { mode: 'off' }));
      await assertFails(setDoc(doc(d, 'config/giving'), { url: 'https://give.example' }));
      await assertFails(setDoc(doc(d, 'config/home'), { sections: [] }));
      await assertFails(setDoc(doc(d, 'config/live'), { isLive: true }));
    }
  });

  test('config/featured accepts auto, pinned and off only', async () => {
    const d = db(superAdmin());
    for (const mode of ['auto', 'pinned', 'off']) {
      await assertSucceeds(setDoc(doc(d, 'config/featured'), { mode }));
    }
    await assertFails(setDoc(doc(d, 'config/featured'), { mode: 'hidden' }));
    await assertSucceeds(deleteDoc(doc(d, 'config/featured')));
  });

  test('config/giving and config/home are shape-checked', async () => {
    const d = db(superAdmin());
    await assertSucceeds(
      setDoc(doc(d, 'config/giving'), {
        url: 'https://give.example',
        bankName: 'Bank',
        accountName: 'Kharis',
        sortCode: '00-00-00',
        accountNumber: '12345678',
        swiftBic: 'BARCGB22',
        iban: 'GB33BUKB20201555555555',
        reference: 'Tithe',
        note: 'Thank you',
      }),
    );
    await assertFails(setDoc(doc(d, 'config/giving'), { url: 'give.example' }));
    await assertFails(setDoc(doc(d, 'config/giving'), { bankName: 42 }));
    await assertFails(setDoc(doc(d, 'config/giving'), { iban: 42 }));
    await assertFails(setDoc(doc(d, 'config/giving'), { swiftBic: ['BARCGB22'] }));
    await assertSucceeds(setDoc(doc(d, 'config/home'), { sections: [{ id: 'reading', enabled: true }] }));
    await assertFails(setDoc(doc(d, 'config/home'), { sections: 'reading' }));
    await assertFails(setDoc(doc(d, 'config/home'), { order: [] }));
  });

  test('config is publicly readable', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'config/home')));
  });
});

describe('users', () => {
  test('member cannot self-promote to campus_admin or admin', async () => {
    const d = db(member());
    await assertFails(updateDoc(doc(d, 'users/member'), { role: 'campus_admin' }));
    await assertFails(updateDoc(doc(d, 'users/member'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(d, 'users/member'), { displayName: 'New name' }));
  });

  test('member cannot self-assign campus lists', async () => {
    const d = db(member());
    await assertFails(updateDoc(doc(d, 'users/member'), { adminBranchIds: ['north'] }));
    await assertFails(updateDoc(doc(d, 'users/member'), { adminBranchNames: ['North'] }));
  });

  test('a new profile cannot carry a privileged role or campus lists', async () => {
    const d = db(env.authenticatedContext('fresh'));
    await assertFails(setDoc(doc(d, 'users/fresh'), { role: 'campus_admin' }));
    await assertFails(setDoc(doc(d, 'users/fresh'), { role: 'member', adminBranchIds: ['north'] }));
    await assertFails(setDoc(doc(d, 'users/fresh'), { role: 'member', adminBranchNames: ['North'] }));
    await assertSucceeds(setDoc(doc(d, 'users/fresh'), { role: 'member' }));
  });

  test('campus admin cannot widen their own role or campuses', async () => {
    const d = db(campusAdmin());
    await assertFails(updateDoc(doc(d, 'users/campus'), { role: 'admin' }));
    await assertFails(updateDoc(doc(d, 'users/campus'), { adminBranchIds: ['north', 'south'] }));
    await assertFails(updateDoc(doc(d, 'users/campus'), { adminBranchNames: ['North', 'South'] }));
    await assertFails(getDoc(doc(d, 'users/member')));
  });

  test('super admin assigns campus_admin with both campus lists', async () => {
    const d = db(superAdmin());
    await assertSucceeds(
      updateDoc(doc(d, 'users/member'), {
        role: 'campus_admin',
        adminBranchIds: ['south'],
        adminBranchNames: ['South'],
      }),
    );
    // The promoted member now manages South only.
    await assertSucceeds(updateDoc(doc(db(member()), 'news/south'), { title: 'edited' }));
    await assertFails(updateDoc(doc(db(member()), 'news/north'), { title: 'edited' }));
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

  test('super admin can still delete any profile', async () => {
    await assertSucceeds(deleteDoc(doc(db(superAdmin()), 'users/member')));
    await assertSucceeds(deleteDoc(doc(db(claimAdmin()), 'users/campus')));
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
    // Not even an admin may touch a member's notes or playlists.
    await assertFails(deleteDoc(doc(db(superAdmin()), 'users/other/notes/n1')));
    await assertFails(deleteDoc(doc(db(superAdmin()), 'users/other/playlists/favorites')));
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
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'motdSchedule/2026-10-04')));
    await assertFails(
      setDoc(doc(db(superAdmin()), 'motdSchedule/2026-10-04'), { sermonId: 's', title: 't' }),
    );
    await assertFails(
      setDoc(doc(db(claimAdmin()), 'motdSchedule/2026-10-04'), { sermonId: 's', title: 't' }),
    );
  });

  test('campus admins stay out of super-admin-only collections', async () => {
    const d = db(campusAdmin());
    await assertFails(setDoc(doc(d, 'sermons/s1'), { title: 'x' }));
    await assertFails(setDoc(doc(d, 'dailyContent/2026-10-04'), { title: 'x' }));
    await assertFails(
      setDoc(doc(d, 'readingPlans/p1'), { startDate: '2026-10-04', book: 'John', days: 21 }),
    );
    await assertFails(getDoc(doc(d, 'visitors/v1')));
    await assertSucceeds(setDoc(doc(db(superAdmin()), 'sermons/s1'), { title: 'x' }));
  });
});

describe('notifications', () => {
  /** A client-written notification by [uid]: "Send now" to [audience]. */
  const compose = (uid: string, audience: Record<string, unknown>, extra: Record<string, unknown> = {}) => ({
    title: 'Prayer night',
    body: 'Friday at 8pm.',
    link: '/e/ev1',
    audience,
    status: 'scheduled',
    sendAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    createdBy: uid,
    createdByName: uid,
    updatedAt: serverTimestamp(),
    ...extra,
  });

  /** Stored docs, as the server would hold them. */
  const stored = (audience: Record<string, unknown>, status: string, createdBy = 'super') => ({
    title: 't',
    body: 'b',
    audience,
    status,
    sendAt: Timestamp.fromMillis(Date.now() + 3_600_000),
    createdAt: Timestamp.now(),
    createdBy,
    updatedAt: Timestamp.now(),
  });

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, 'notifications/north'), stored({ type: 'branch', branch: 'North' }, 'scheduled', 'campus'));
      await setDoc(doc(d, 'notifications/south'), stored({ type: 'branch', branch: 'South' }, 'scheduled'));
      await setDoc(doc(d, 'notifications/all'), stored({ type: 'all' }, 'scheduled'));
      await setDoc(doc(d, 'notifications/test'), stored({ type: 'test' }, 'draft'));
      await setDoc(doc(d, 'notifications/sentAll'), {
        ...stored({ type: 'all' }, 'sent'),
        sentAt: Timestamp.now(),
        result: { messageId: 'm1' },
      });
      await setDoc(doc(d, 'notifications/sentNorth'), {
        ...stored({ type: 'branch', branch: 'North' }, 'sent'),
        sentAt: Timestamp.now(),
      });
      await setDoc(doc(d, 'notifications/sentTest'), stored({ type: 'test' }, 'sent'));
      await setDoc(doc(d, 'notifications/failed'), {
        ...stored({ type: 'all' }, 'failed'),
        result: { error: 'x' },
      });
    });
  });

  test('super admin (role or claim) sends to any audience', async () => {
    for (const audience of [{ type: 'all' }, { type: 'test' }, { type: 'branch', branch: 'South' }]) {
      await assertSucceeds(setDoc(doc(db(superAdmin()), `notifications/s_${audience.type}`), compose('super', audience)));
    }
    await assertSucceeds(setDoc(doc(db(claimAdmin()), 'notifications/c1'), compose('claim', { type: 'all' })));
  });

  test('branch admin sends to own branch and test only', async () => {
    const d = db(campusAdmin());
    await assertSucceeds(setDoc(doc(d, 'notifications/n1'), compose('campus', { type: 'branch', branch: 'North' })));
    await assertSucceeds(setDoc(doc(d, 'notifications/n2'), compose('campus', { type: 'test' })));
    await assertFails(setDoc(doc(d, 'notifications/n3'), compose('campus', { type: 'all' })));
    await assertFails(setDoc(doc(d, 'notifications/n4'), compose('campus', { type: 'branch', branch: 'South' })));
  });

  test('a branch admin without branches, and members, send nothing', async () => {
    await assertFails(setDoc(doc(db(member()), 'notifications/m1'), compose('member', { type: 'branch', branch: 'North' })));
    await assertFails(setDoc(doc(db(member()), 'notifications/m2'), compose('member', { type: 'test' })));
    await assertFails(
      setDoc(doc(env.unauthenticatedContext().firestore(), 'notifications/u1'), compose('anon', { type: 'all' })),
    );
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/campus'), { role: 'campus_admin' });
    });
    await assertFails(setDoc(doc(db(campusAdmin()), 'notifications/n5'), compose('campus', { type: 'test' })));
  });

  test('createdBy must be the caller', async () => {
    await assertFails(setDoc(doc(db(superAdmin()), 'notifications/x'), compose('someone-else', { type: 'all' })));
  });

  test('clients cannot write server statuses or server fields', async () => {
    const d = db(superAdmin());
    for (const status of ['sending', 'sent', 'failed']) {
      await assertFails(setDoc(doc(d, `notifications/st_${status}`), compose('super', { type: 'all' }, { status })));
    }
    await assertFails(setDoc(doc(d, 'notifications/c1'), compose('super', { type: 'all' }, { status: 'cancelled' })));
    await assertFails(setDoc(doc(d, 'notifications/sa'), compose('super', { type: 'all' }, { sentAt: serverTimestamp() })));
    await assertFails(
      setDoc(doc(d, 'notifications/rs'), compose('super', { type: 'all' }, { result: { messageId: 'fake' } })),
    );
    await assertFails(updateDoc(doc(d, 'notifications/all'), { status: 'sent' }));
    await assertFails(updateDoc(doc(d, 'notifications/all'), { sentAt: serverTimestamp() }));
  });

  test('shape: title/body lengths, link, audience, sendAt', async () => {
    const d = db(superAdmin());
    const all = { type: 'all' };
    await assertSucceeds(setDoc(doc(d, 'notifications/ok65'), compose('super', all, { title: 'x'.repeat(65), body: 'y'.repeat(240) })));
    await assertSucceeds(setDoc(doc(d, 'notifications/nolink'), compose('super', all, { link: null })));
    await assertSucceeds(setDoc(doc(d, 'notifications/https'), compose('super', all, { link: 'https://kharis.org/x' })));
    const bad: Record<string, unknown>[] = [
      { title: '' },
      { title: '   ' },
      { title: 'x'.repeat(66) },
      { body: '' },
      { body: 'y'.repeat(241) },
      { link: 'javascript:alert(1)' },
      { link: '//evil.example' },
      { link: `/${'x'.repeat(500)}` },
      { link: 42 },
      { audience: { type: 'everyone' } },
      { audience: { type: 'branch' } },
      { audience: { type: 'branch', branch: ' ' } },
      { audience: { type: 'all', branch: 'North' } },
      { audience: 'all' },
      { sendAt: null },
      { extra: true },
    ];
    for (const [i, change] of bad.entries()) {
      await assertFails(setDoc(doc(d, `notifications/bad${i}`), compose('super', all, change)));
    }
    await assertSucceeds(setDoc(doc(d, 'notifications/draft'), compose('super', all, { status: 'draft', sendAt: null })));
  });

  test('cancel: only from draft/scheduled, by someone who manages the audience', async () => {
    const cancel = { status: 'cancelled', updatedAt: serverTimestamp() };
    const c = db(campusAdmin());
    await assertSucceeds(updateDoc(doc(c, 'notifications/north'), cancel));
    await assertSucceeds(updateDoc(doc(c, 'notifications/test'), cancel));
    await assertFails(updateDoc(doc(c, 'notifications/south'), cancel));
    await assertFails(updateDoc(doc(c, 'notifications/all'), cancel));
    const s = db(superAdmin());
    await assertSucceeds(updateDoc(doc(s, 'notifications/all'), cancel));
    await assertFails(updateDoc(doc(s, 'notifications/sentAll'), cancel));
    await assertFails(updateDoc(doc(s, 'notifications/failed'), cancel));
    // Once cancelled it stays cancelled.
    await assertFails(updateDoc(doc(s, 'notifications/all'), { status: 'scheduled', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db(member()), 'notifications/south'), cancel));
  });

  test('branch admin cannot retarget a notification off their branches', async () => {
    const c = db(campusAdmin());
    await assertFails(updateDoc(doc(c, 'notifications/north'), { audience: { type: 'branch', branch: 'South' } }));
    await assertFails(updateDoc(doc(c, 'notifications/north'), { audience: { type: 'all' } }));
    await assertSucceeds(updateDoc(doc(c, 'notifications/north'), { audience: { type: 'test' } }));
    await assertFails(updateDoc(doc(c, 'notifications/south'), { audience: { type: 'branch', branch: 'North' } }));
  });

  test('creator and creation time are immutable; nobody deletes', async () => {
    const s = db(superAdmin());
    await assertFails(updateDoc(doc(s, 'notifications/all'), { createdBy: 'campus' }));
    await assertFails(updateDoc(doc(s, 'notifications/all'), { createdAt: Timestamp.fromMillis(0) }));
    await assertFails(deleteDoc(doc(s, 'notifications/all')));
  });

  test('members read only sent pushes to everyone or a branch', async () => {
    for (const d of [db(member()), env.unauthenticatedContext().firestore()]) {
      await assertSucceeds(getDoc(doc(d, 'notifications/sentAll')));
      await assertSucceeds(getDoc(doc(d, 'notifications/sentNorth')));
      for (const id of ['sentTest', 'all', 'north', 'test', 'failed']) {
        await assertFails(getDoc(doc(d, `notifications/${id}`)));
      }
    }
  });

  test('inbox queries must constrain status and audience; admins list everything', async () => {
    const d = db(member());
    const col = collection(d, 'notifications');
    await assertSucceeds(
      getDocs(query(col, where('status', '==', 'sent'), where('audience.type', '==', 'all'), orderBy('sentAt', 'desc'), limit(50))),
    );
    await assertSucceeds(
      getDocs(
        query(
          col,
          where('status', '==', 'sent'),
          where('audience.type', '==', 'branch'),
          where('audience.branch', '==', 'North'),
          orderBy('sentAt', 'desc'),
          limit(50),
        ),
      ),
    );
    await assertFails(getDocs(query(col, where('status', '==', 'sent'), limit(50))));
    await assertFails(getDocs(query(col, limit(50))));
    for (const ctx of [superAdmin(), campusAdmin()]) {
      await assertSucceeds(getDocs(query(collection(db(ctx), 'notifications'), orderBy('createdAt', 'desc'), limit(50))));
    }
  });
});
