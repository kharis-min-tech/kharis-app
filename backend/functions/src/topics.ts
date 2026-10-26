/**
 * FCM topic naming — the single server-side implementation.
 *
 * Devices subscribe under the client's slug (`KharisTopics.slugifyBranch` in
 * `app/lib/core/services/notification_service.dart`), so this MUST stay
 * character-identical to it. Any drift is silent: pushes land on a topic
 * nobody is listening on and nothing reports an error.
 */

/** Branch name -> FCM topic suffix, e.g. `KP2 London` -> `kp2-london`. */
export function slugifyBranch(name: string): string {
  return name.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-');
}

/**
 * Topic for a piece of branch-scoped content: `branch_<slug>` when the content
 * names a branch, `all` when it is church-wide (null/blank branch). Every
 * device is subscribed to `all`; branch topics follow the member's selection.
 */
export function branchTopic(branch?: string | null): string {
  const name = (branch ?? '').toString().trim();
  return name ? `branch_${slugifyBranch(name)}` : 'all';
}

/** Where a push goes: one topic, or an FCM topic condition. */
export type PushAudience = { topic: string } | { condition: string };

/**
 * FCM topics behind the app's notification preference toggles. MUST match
 * `KharisTopics.events` / `KharisTopics.serviceReminders` /
 * `KharisTopics.dailyReading` / `KharisTopics.muteAnnouncements` in
 * `app/lib/core/services/notification_service.dart`.
 *
 * `dailyReading` is `daily_reading_v2`: app builds that validate the reading
 * subscribe to it and leave `legacyDailyReading` (`daily_reading`), the topic
 * an earlier reading-plan push sent invented chapters to.
 *
 * `muteAnnouncements` is the one opt-OUT topic: a device joins it when the
 * member turns Announcements off. App builds from before that toggle never
 * join it, so they keep receiving announcements.
 */
export const PREF_TOPIC = {
  events: 'events',
  serviceReminders: 'service_reminders',
  dailyReading: 'daily_reading_v2',
  legacyDailyReading: 'daily_reading',
  muteAnnouncements: 'mute_announcements',
} as const;

/**
 * Where the daily reading goes: current app builds on `daily_reading_v2`, and
 * older builds still only on `daily_reading` (never both, so nobody gets it
 * twice).
 */
export const READING_AUDIENCES: readonly PushAudience[] = [
  { topic: PREF_TOPIC.dailyReading },
  {
    condition:
      `'${PREF_TOPIC.legacyDailyReading}' in topics && ` +
      `!('${PREF_TOPIC.dailyReading}' in topics)`,
  },
];

/**
 * Devices that opted into [prefTopic] AND follow [branch]'s campus, so turning
 * a toggle off in the app really stops that kind of push. Every device is on
 * `all`, so all-campus content reduces to "opted in".
 */
export function prefAudience(prefTopic: string, branch?: string | null): PushAudience {
  return { condition: `'${prefTopic}' in topics && '${branchTopic(branch)}' in topics` };
}

/**
 * Where an announcement for [branch] goes: devices on that campus's topic
 * (`all` for church-wide notices) that have not muted announcements.
 */
export function announcementAudience(branch?: string | null): PushAudience {
  return {
    condition: `'${branchTopic(branch)}' in topics && !('${PREF_TOPIC.muteAnnouncements}' in topics)`,
  };
}
