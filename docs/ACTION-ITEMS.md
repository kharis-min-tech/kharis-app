# Action items — per person (as of 8 Sep 2026)

From the 31 Aug meeting plan + everything agreed in chat since. WhatsApp-friendly:
copy a person's block straight into the group. ✅ = confirmed done in chat.

## App team

*Jonathan*
- Answer Daniel's caching question for the R2/Worker sermon pipeline (asked 8 Sep) — propose TTL/invalidations
- Push the frontend↔R2 changes to a branch for team build/review (promised 7 Sep — confirm)
- Minor frontend tweaks now Cloudflare access exists
- ✅ Media engine deployed: Worker + R2 live, frontend fetching (7 Sep)
- ✅ Frontend connected to media-engine backend (31 Aug)

*Ayo*
- Fix KA-001 giving-flow obstruction (acknowledged 30 Aug) — highest priority
- Fix KA-013 duplicate share button (acknowledged 3 Sep)
- Work through P1/P2 list in docs/BUG-TRACKER.md
- Answer NJ's Firebase question: backend currently runs on `kharis-church` (personal project, ayoinc = Owner) — see INTEGRATION_ISSUES §2; NJ should liaise with you + Daniel for schema additions
- ✅ PR #6 raised (29 Aug) and approved (2 Sep)

*Kenny*
- Bug sheet: use docs/bug-tracker.csv as the seed → convert to tickets → assign owners
- Reschedule the app-team catch-up (1 Sep call skipped)
- Activate tester pools: ~10 Android + ~10 iOS, tell them to actually test (links already live)
- Pull NJ's Apple-feedback-tracker submissions into the tracker (Q-3)

*Dami*
- Join rescheduled app-team call (Tuesday clash noted — pick another day)
- Take assigned tickets once Kenny distributes

## Content Studio / Data

*NJ*
- Circulate DB design for review (sent 3 Sep — collect sign-off)
- ⚠ Align datastore direction with docs/CONTENT-STUDIO-CONSOLIDATION.md + BACKLOG §2 before building further: agreed direction was studio-on-Firestore, Supabase for reporting/relational only — raise at Sunday meeting
- Confirmed app-specific content set (2 Sep): announcements, daily reading, daily prayers, daily message, events/calendar (+ branch meeting times, shared with web)
- Send the playback-bar example Daniel asked for (Q-2)
- ✅ AWS access, Supabase access + DB activated

*Kalvert*
- Support NJ on Content Studio + codebase merge
- Hold website ETA: end of week 1 / start of week 2 of September

## Web team

*David*
- Finish Children's Ministry section; final checks on all buttons/functionality
- Add small filter to Messages section; upload latest code to GitHub

*Fidele*
- Testimonial page final touches + carousel; UI touch-ups
- Remove sensitive data (Koc & Kocc); placeholders for department showcase videos
- ✅ GitHub access

## Platform (Daniel)

- Respond on caching with Jonathan (Q-1)
- Review NJ's DB design
- Flag org-project blocker upward: `kharis-app-47c49` is Spark/no billing — an org admin must link Blaze billing before backend can move off the personal project (INTEGRATION_ISSUES §2)
- ✅ All access grants done: GitHub (Fidele, Dami), Cloudflare + R2 admin (Jonathan), AWS (NJ), Supabase (app team + NJ, developer perms, DB activated), PR review, calendar invites

## Product decisions needed (Pastor Luke)

1. Daily Prayer — expected behaviour on tap (KA-010)
2. First-load branch prompt / default London (KA-011)
3. Sign-off: daily reading's new Home placement (KA-009)
4. LTBS rollout scope — minimum feature set to ship
- ✅ Decided: offline playback (YT-Music-style), not mp3 downloads (27 Aug)
- ✅ Decided: ratings pop-up quarterly + always-available menu button (5 Sep)
