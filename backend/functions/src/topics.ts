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
