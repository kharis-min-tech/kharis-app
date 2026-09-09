# Bug & UX Tracker — tester rounds 1–2

Compiled from the app-team WhatsApp chat (19 Aug – 8 Sep 2026): NJ's rounds (24 Aug,
30–31 Aug, 3 Sep) + Pastor Luke's external tester review (27 Aug) + product decisions.

Scope: **bugs and UX fixes only.**
- Larger feature asks → `docs/BACKLOG.md` (registrations hub, I AM KHARIS, prayer network, offline, AI…)
- Server/API-side issues → `docs/INTEGRATION_ISSUES.md` (P0: `?series=`/`?playlist=` filters ignored)
- CSV twin for Kenny's Excel sheet → `docs/bug-tracker.csv`

Status values: `Open` · `Ack` (owner aware) · `Needs-repro` · `Needs-decision` · `Decided` (to implement) · `Data` (CMS/content-side, not app code) · `Done`

> **Fix pass, 9 Sep 2026:** statuses reflect the **repo**, not the 30 Aug TestFlight build.
> Many "already in repo (build lag)" fixes simply need the next build cut for testers to see them.

## P0 — blocks core value

| ID | Title | Area | Source | Owner | Status | Notes |
|---|---|---|---|---|---|---|
| KA-001 | Playback mini-bar can't be dismissed during giving — obstructs the giving flow | Giving / Player | NJ, 30 Aug | Ayo | Done | 9 Sep: bar auto-hides on the Giving tab (audio keeps playing; returns on other tabs) + swipe-down dismiss was already in repo |
| KA-002 | Event-calendar notification won't open; needs date/time/venue detail | Notifications / Events | Tester, 27 Aug | — | Done | Already in repo (tested build predates it): feed rows open a detail sheet with date/time/venue + add-to-calendar; FCM taps deep-link. Verify on next TestFlight |
| KA-003 | Sermon notes can't be retrieved after creation | Notes | Tester 27 Aug + NJ 24 Aug | — | Done | Already in repo (build lag): More → My Notes (`/notes`) + player Notes sheet; notes persistence tests green |
| KA-004 | Reading Plan button doesn't open a Bible; Bible failed to load (19 Aug) | Reading Plan | Pastor Luke 19 Aug + tester | — | Done | Already in repo (build lag): full in-app reader at `/reading` (version switcher, error view). Decision landed: in-app reader, not external intent |

## P1 — high-visibility fixes & placement

| ID | Title | Area | Source | Owner | Status | Notes |
|---|---|---|---|---|---|---|
| KA-005 | Video scrubbing clunky / laggy | Player | Tester, 27 Aug | — | Open | youtube_player_iframe constraint? Investigate seek throttling |
| KA-006 | No sound during video intro (recovered afterwards) | Player | Tester, 27 Aug | — | Needs-repro | Possibly content-side; capture video ID next time |
| KA-007 | Page with no way back (NJ screenshot) | Navigation | NJ, 24 Aug | — | Done | 9 Sep route audit: every pushed route has AppBar back; Browse has an explicit home exit; exit regression covered by playlist_detail_exit_test. Reopen with Q-2 screenshot if it recurs |
| KA-008 | Share only copies link — no native share sheet | Sharing | Tester, 27 Aug | — | Done | Already in repo (build lag): OS share sheet via share_plus with a `youtu.be` link (`share_sermon.dart`) |
| KA-009 | Daily reading needs a more prominent Home position | Home | Pastor Luke, 19 Aug | — | Done | 9 Sep: Today's Reading is now the first Home block, above the hero message |
| KA-010 | Daily Prayer tap behaviour undefined | Daily Prayer | NJ, 24 Aug | — | Needs-decision | What is expected functionality? (Pastor Luke to define) |
| KA-011 | First-load branch prompt; default to London instead of all-branch events | Onboarding / Events | NJ, 24 Aug | — | Needs-decision | One-time branch prompt is already in repo (`_promptBranchOnce`). Open half: which branch to default to when a member skips the prompt |
| KA-012 | Ratings/feedback: quarterly pop-up + permanent menu button | Engagement | Daniel + Pastor Luke, 5 Sep | — | Done | 9 Sep: More → Rate & Feedback + quarterly nudge (≥3 sessions, never over another prompt). Native review via in_app_review; graceful fallback under TestFlight |

## P2 — polish

| ID | Title | Area | Source | Owner | Status | Notes |
|---|---|---|---|---|---|---|
| KA-013 | Duplicate share buttons (top + bottom) | Player UI | NJ, 3 Sep | Ayo | Done | 9 Sep: header share removed; single share lives in the Notes · Playlist · Share row |
| KA-014 | Search bar square when idle, circular when active | UI consistency | NJ, 24 Aug | — | Done | Already in repo (build lag): pill container in both idle and focused states |
| KA-015 | Scrolling possible on the message-viewing surface | Player UI | NJ, 24 Aug | — | Done | Already in repo (build lag): video surface pinned outside the scrollable |
| KA-016 | "Continue as guest" doesn't read as tappable | Onboarding | NJ, 24 Aug | — | Done | Already in repo (build lag): full-width outlined button with border + radius |
| KA-017 | Rewind/forward 10s buttons need styling touch-up | Player UI | NJ, 24 Aug | — | Done | Already in repo (build lag): tonal circle buttons with ripple + larger tap targets |
| KA-018 | Video container styling — sharp corners, feels "slapped on" | Player UI | NJ, 24 + 30 Aug | — | Done | Already in repo (build lag): corner mask rounds the platform view; ambient gradient ties it to the page |
| KA-019 | Previously-viewed + not-finished filters in library | Library | NJ, 31 Aug | — | Open | Enhancement; pairs with resume-playback state |
| KA-020 | Notifications bell missing in build under test | Home | NJ, 31 Aug | — | Done | Verified in repo: Home header bell + dot opens the notifications feed; tested build predated it |
| KA-023 | Bell dot always lit — contradicted an empty feed | Home | Real-device walkthrough, 9 Sep | — | Done | Found on iPhone: fresh install showed the unread dot over "No notifications yet". Dot was hard-coded; now driven by `hasPendingNotificationsProvider` (feed rows minus dismissed, off while loading). Unit + on-device check |
| KA-024 | Swiping the mini-player away asserted on device ("dismissed Dismissible still in the tree") | Player | Real-device walkthrough, 9 Sep | — | Done | Engine clears the sermon a frame late; bar now hides itself synchronously on dismiss and resets when the sermon clears. Widget test models the late engine; on-device swipe re-verified |

## Data / CMS-side (not app code)

| ID | Title | Source | Status | Notes |
|---|---|---|---|---|
| KA-021 | Branch locations: only Kharis Phase 2 + Chatham maps work | Tester, 27 Aug | Data | CMS data completeness — see BACKLOG.md §7 |
| KA-022 | Catalogue gaps (Phase 2 vs Main Service London; "not all messages") | Tester, 27 Aug | Data | Catalogue/CMS-side + API P0 filter bug (INTEGRATION_ISSUES §1). Catalogue ≈1,481 (31 Jul probe) → 1,483 (19 Aug) |

## Open questions

| ID | Question | Raised | Waiting on |
|---|---|---|---|
| Q-1 | Caching strategy for the R2/Worker sermon pipeline | Daniel, 8 Sep | Jonathan |
| Q-2 | NJ's playback "bar vs bar" question — example requested | 3–5 Sep | NJ (send screenshot) |
| Q-3 | Export NJ's Apple-feedback-tracker submissions (30 Aug) into this tracker | 30 Aug | Kenny |

## Corrections vs chat assumptions (from repo docs)

- **Playlists**: creation *exists*; the issue is discoverability (BACKLOG §8) — not a missing feature.
- **YouTube viewership**: in-app watching **does** count (youtube_player_iframe) — keep, answer the tester's question.
- **Branch maps / catalogue gaps**: data problems, not app bugs (KA-021/KA-022).

## Fix log — 9 Sep 2026 pass

Code changes made this pass (all `flutter analyze` clean; full test suite 106/106 green):

1. **KA-001** `dashboard_shell.dart` — mini-player no longer renders on the Giving tab; audio keeps playing and the bar returns on any other tab. Swipe-down dismiss (already in repo) unchanged.
2. **KA-013** `media_player_screen.dart` — header share icon removed (40px spacer keeps the series label centred); the actions-row share is now the single affordance.
3. **KA-009** `home_screen.dart` — Today's Reading moved above the hero message as the first content block.
4. **KA-012** new `features/settings/presentation/widgets/feedback_sheet.dart` + More-menu row + `in_app_review ^2.0.9` — `FeedbackSheet` (Rate the app / Send feedback / Not now) and `FeedbackNudge` (quarterly, ≥3 sessions, skips if another surface owns the screen, e.g. the branch prompt).

Still open after this pass: KA-005 (scrub feel — needs device testing), KA-006 (needs repro), KA-010 (needs Pastor Luke's definition), KA-011 (default-branch half), KA-019 (filters — enhancement), KA-021/KA-022 (data/CMS), Q-1–Q-3.
