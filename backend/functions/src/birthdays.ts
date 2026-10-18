/**
 * Whether a `users` doc returned by the `dobMMDD == monthDay` query should
 * get today's birthday push: its `dob` (yyyy-mm-dd) really falls on
 * [monthDay] (`MM-DD`) and it has a device token.
 */
export function isBirthdayCelebrant(
  data: { dob?: unknown; fcmToken?: unknown },
  monthDay: string,
): boolean {
  return (
    typeof data.dob === 'string' &&
    data.dob.slice(5) === monthDay &&
    typeof data.fcmToken === 'string' &&
    data.fcmToken.length > 0
  );
}
