import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getMessaging } from 'firebase-admin/messaging';
import { LONDON } from './london-time';
import { pushState, purgePushState } from './push-state';
import {
  BRANCH_RUN_EVERY_MS,
  EVENT_RUN_EVERY_MS,
  PollResult,
  StudioPushDeps,
  runAnnouncementPush,
  runBranchUpdatePush,
  runEventPush,
  runServiceReminderPush,
} from './studio-pushes';
import { REMINDER_RUN_EVERY_MS } from './service-reminders';

/**
 * Content Studio -> device pushes. The Studio writes Supabase only, so each
 * of these polls its tables on a schedule (`studio-pushes.ts` for what is
 * sent and when) and keeps its bookkeeping in `push-state.ts`.
 */

const deps: StudioPushDeps = {
  fetchImpl: fetch,
  state: pushState,
  send: ({ audience, title, body, data }) =>
    getMessaging().send({
      ...audience,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    }),
};

const minutes = (ms: number) => `every ${ms / 60_000} minutes`;

const log = (name: string, { sent, failed }: PollResult) =>
  console.log(`[${name}] ${sent} sent, ${failed} failed`);

/**
 * Studio announcements published in the last 15 minutes, each pushed once.
 * Every minute: a notice reaches phones within a minute of publishing, and a
 * bad run still leaves 14 minutes of retries before it ages out.
 */
export const pushPendingAnnouncements = onSchedule(
  { schedule: 'every 1 minutes', timeZone: LONDON, memory: '256MiB', timeoutSeconds: 60 },
  async () => log('announcements', await runAnnouncementPush(deps, Date.now())),
);

/** New and rescheduled, moved or renamed Studio events. */
export const pushEventUpdates = onSchedule(
  { schedule: minutes(EVENT_RUN_EVERY_MS), timeZone: LONDON, memory: '256MiB', timeoutSeconds: 120 },
  async () => log('events', await runEventPush(deps, Date.now())),
);

/** Changed service days, times or venues of a branch. */
export const pushBranchUpdates = onSchedule(
  { schedule: minutes(BRANCH_RUN_EVERY_MS), timeZone: LONDON, memory: '256MiB', timeoutSeconds: 60 },
  async () => log('branches', await runBranchUpdatePush(deps)),
);

/** A reminder an hour before each branch service. */
export const pushServiceReminders = onSchedule(
  { schedule: minutes(REMINDER_RUN_EVERY_MS), timeZone: LONDON, memory: '256MiB', timeoutSeconds: 60 },
  async () => log('service-reminder', await runServiceReminderPush(deps, Date.now())),
);

/**
 * Deletes push claims past their 30-day retention and saved snapshots past
 * their `keepUntil` (`push-state.ts`).
 */
export const purgePushLog = onSchedule(
  { schedule: 'every day 03:30', timeZone: LONDON, memory: '256MiB', timeoutSeconds: 300 },
  async () => {
    console.log(`[push] purged ${await purgePushState(Date.now())} expired record(s)`);
  },
);
