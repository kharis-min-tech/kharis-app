# Backlog — agreed-future items (Aug 18 product call)

Design notes so these start from a shared understanding, not from zero.
None of these block the current release train.

## 1. Birthday pushes — ✅ shipped (server + groundwork)

What exists now:
- App collects optional `dob` + `phone` post-signup (Edit Profile; home card
  nudges until complete — signup itself stays minimal).
- App saves the device token to `users/{uid}.fcmToken` on sign-in/refresh.
- `pushBirthdays` scheduled function: daily 08:00 Europe/London, matches
  `dob` month-day, direct token push, `birthdayPushes/{date}` idempotency
  marker, dead-token pruning.

Future niceties: grouped "celebrating this week" digest for branch admins;
in-app confetti card on the member's own birthday; scale path is a `dobMMDD`
field + indexed query once users > ~2k.

## 2. Supabase ("superbizz") exploration

Context from the call: interest in a Postgres-backed alternative (Supabase)
hosted outside Google, for cost control and SQL ergonomics; the admin dev
uses MongoDB/Golang day-to-day and wants a comfortable backend.

Recommendation (short): **stay on Firestore for this app's core** —
realtime listeners power live status, admin instant-reflection and branch
scoping; FCM, Auth (SCRYPT hash import already done once), rules and the
five deployed workers are all Firebase-native. Re-platforming buys no member
-visible feature today.

Where Supabase *is* a good fit to trial first:
- The consolidated church-website Content Studio's *reporting* views
  (SQL aggregations Firestore is bad at: attendance trends, RSVP funnels).
- Any future relational data (rotas, follow-up pipelines).

Suggested spike (1 day, throwaway): mirror `events` + `rsvps` into a free
Supabase project via a scheduled export function; build one SQL dashboard
query; measure effort vs value. Exit criteria: written comparison of auth
model, rules parity, offline story, and egress costs before any commitment.

## 3. AI-assisted upload

Goal from the call: reduce the Sunday-admin burden when publishing sermons.
Sketch:
- Admin drops a raw recording link (or YouTube URL) into Content Studio.
- Worker fetches metadata; speech-to-text on the first minutes; an LLM
  proposes title, speaker, series, scripture reference, topic tags and a
  one-line summary; admin reviews and accepts (never auto-publish).
- Builds on the existing `searchYouTube` function + sermon write path;
  needs a transcription provider decision (cost per hour of audio) and a
  human-in-the-loop review screen in the studio.

First slice: "propose metadata from YouTube URL" only (no audio processing)
— title/speaker/series parsing is already 80% regex on our own naming
convention, LLM fills the rest.
