# Spec: Consolidate Content Studio into the main church website

**Status:** agreed direction (Aug 18 product call) · **Owner:** tech team · **Depends on:** none (can start any time)

## Why

Today there are **two Content Studio surfaces** with the same Firestore-backed
contract but entirely separate codebases:

1. **Web portal** — `admin/index.html` (single self-contained file: markup, CSS
   and a `<script type="module">` using the Firebase web SDK directly; deployed
   to `kharis-app-admin.web.app` via `firebase deploy --only hosting`).
2. **In-app admin** — Flutter screens under `app/lib/features/admin/`
   (`~10 screens`, gated by `isAdminProvider`).

They overlap heavily and every drift bug we have shipped (`description` vs
`subtitle`, `14:00` vs `2:00 PM`, UTC-midnight `publishedAt`) came from the two
implementations interpreting one contract differently. The product decision
from the call: **content management should live in one place, reachable from
the main church website**, so a branch admin has a single door.

## Decision

- The web Content Studio becomes a **section of the main church website**
  (e.g. `kharischurch.org/studio`), not a separate hosting site. Same Firebase
  project (`kharis-app-47c49`), same auth, same collections — only the front
  door moves.
- The **in-app admin stays** for quick phone-side edits, but is treated as a
  *client* of the same contract; any schema change lands in a shared reference
  first (below), then both UIs.
- The standalone `kharis-app-admin.web.app` site remains as a redirect for one
  quarter, then is retired.

## Contract (single source of truth)

Create `docs/CONTENT-CONTRACT.md` capturing what "Content Studio" means — the
four behaviours we verified end-to-end this cycle:

| Area | Studio sets | Drives in app |
|---|---|---|
| Announcements | title, body, image, type, **branch**, publish/expiry | Home carousel + notification bell |
| Events | title, date/time, location, branch, image, featured | Events tab, RSVP, Upcoming/Past |
| Sermons | feature/unfeature (star), MOTD (sunlight), YouTube search | Messages hero, library, Message of the Day |
| Daily reading | plans (book, start date, advance rule, verse ranges) | Home "Today's Reading", daily 06:00 push |

Rules already enforced and to keep: branch scoping (`'branch' == null` = all
campuses, explicit null), push on create/meaningful edit (`onEventWritten`,
`onBranchVenueWritten`, `pushPendingAnnouncements`, `pushDailyReading`),
publish-timestamp = now when the chosen date is today, expired plans pin to
their last day.

## Migration steps

1. **Extract** the `<script>` from `admin/index.html` into `admin/studio.js`
   (no behaviour change; the file is ~2.5k lines and needs a module boundary
   before it can be embedded).
2. **Namespace styles** (prefix `.ks-`) so the studio can sit inside the church
   site's layout without collisions.
3. Add a `/studio` route on the church website that lazy-loads the studio
   bundle after a Firebase Auth sign-in with `admin` role (same
   `isAdminProvider` semantics as the app: custom claim or profile role).
4. Point DNS/hosting: church site keeps its host; studio ships as part of that
   deploy. Keep `firebase.json` hosting target for the old admin site serving
   a meta-refresh redirect for 90 days.
5. Delete the redirect + old target after the quarter.

## Out of scope (tracked separately in docs/BACKLOG.md)

- Supabase/"superbizz" backend exploration — studio consolidation must not
  couple to a datastore decision; the studio talks to the same repositories.
- AI-assisted upload.
- Member-facing church website redesign.

## Acceptance

- One URL on the church domain where an admin can do everything the portal
  does today (all four areas), with the app reflecting changes live.
- `admin/index.html` no longer contains inline app logic (only the shell).
- Old admin URL redirects; no bookmarks break during the transition quarter.
