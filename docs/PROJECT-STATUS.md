# Kharis — whole-project status

**Snapshot:** 8 Sep 2026 (compiled from app-team chat 19 Aug – 8 Sep + repo docs).
Sections marked ⏳ await context from the other teams' chats.

**Product:** Kharis Church app + website + Content Studio. Audio is the hero
feature (PRODUCT.md); dark-mode-first, purple `#6B34FA`.

## Milestones

| When | What | Status |
|---|---|---|
| End wk 1 / start wk 2 Sep | Website launch (Kalvert, 28 Aug) | 🟡 already reacted to as tight ("that's next week") |
| LTBS | "Something to roll out" (Pastor Luke, 28 Aug) | 🔴 scope undefined — rehearsals already running (7 Sep) |
| Sundays, ~22:00 | Weekly all-hands (Teams; invite now in calendars) | 🟢 recurring |

## Workstreams

| Stream | Owner(s) | State | Next |
|---|---|---|---|
| Mobile app (Flutter) | Ayo · QA Kenny · Dami | Feedback rounds 1–2 in; PR #6 approved 2 Sep | Work docs/BUG-TRACKER.md, P0s first (giving-flow KA-001) |
| Media pipeline | Jonathan | ✅ Cloudflare Worker + R2 live 7 Sep; app fetches from R2; stores **URLs only** (audio stays on yetanothersermon) | Caching strategy (Q-1); push branch for team build |
| Content Studio | NJ (+ Kalvert) | Building "universal" studio web app; DB schema drafted 3 Sep; app-specific content agreed 2 Sep | ⚠ Resolve datastore direction (risk R1) |
| Website | Kalvert · David · Fidele | Final tweaks; backend WIP | Children's Ministry, testimonials/carousel, messages filter, sensitive-data removal |
| Backend / data | Ayo (Firebase) · Daniel (platform) | Firestore + functions live on `kharis-church` (personal project); Supabase project activated for studio work | Org billing unblock (R2 risk); DB design review |
| QA / testing | Kenny | iOS public TestFlight + Android internal track live; ~10 testers per platform planned; unbiased-feedback protocol agreed (Fidele, 20 Aug) | Activate testers; tickets from bug sheet |

## Decision log

| Date | Decision |
|---|---|
| 18 Aug (product call) | Content Studio consolidates into church website (`/studio`), Firestore contract stays single source of truth; Supabase = reporting/relational trial only (BACKLOG §2, CONTENT-STUDIO-CONSOLIDATION.md) |
| 27 Aug | Offline listening = in-app offline playback (YT-Music-style); **no** raw mp3 downloads |
| 30 Aug | Content Studio to be universal (app + website) as a web application (NJ + Ayo) |
| 2 Sep | App-specific studio content: announcements, daily reading, daily prayers, daily message, events (+ branch meeting locations/times, shared with web) |
| 5 Sep | Ratings prompt: quarterly pop-up + permanent menu button |
| 7–8 Sep | R2 stores sermon URLs only, not audio files |

## Risks / needs alignment

1. **R1 — Datastore divergence.** The 18 Aug direction (studio on the existing
   Firestore contract; Supabase only for reporting) vs the 30 Aug+ build (NJ's
   universal studio on a new Supabase schema). Two write-paths for the same
   content is exactly the drift-bug class the consolidation spec documents
   (`description` vs `subtitle`, time formats, UTC `publishedAt`). **Decide at
   Sunday meeting before more schema work.**
2. **R2 — Backend on a personal Firebase project.** Production runs on
   `kharis-church` (ayoinc = Owner, Blaze). Org project `kharis-app-47c49` is
   Spark with no billing; org admin action needed (INTEGRATION_ISSUES §2).
   Bus-factor + governance risk.
3. **R3 — Caching undefined** on the new R2/Worker pipeline ahead of LTBS
   traffic (Q-1, unanswered 8 Sep).
4. **R4 — Sermon API P0:** `?series=`/`?playlist=` ignored server-side; series/
   playlist views incomplete beyond fetched pages (~200 of ~1,481). Fix is
   server-side or must be absorbed by the R2 mirror (INTEGRATION_ISSUES §1).
5. **R5 — Tester pools not activated.** Links live since 19–24 Aug; "we need to
   update them that they need to test" (Pastor Luke). Feedback so far is from
   2–3 insiders + one outsourced tester.
6. **R6 — Deadline compression.** Website ETA + LTBS target vs open P0s.
7. **R7 — Meeting cadence fragility.** 1 Sep app-team call silently skipped;
   Dami has a standing Tuesday clash.

## Cross-team dependencies

- Content Studio (NJ) → blocks app dynamic content (announcements, dailies, events) **and** website content — dependent on R1 decision.
- Media pipeline (Jonathan) → app Messages tab quality; depends on caching decision (Daniel/Jonathan) and yetanothersermon server fixes (R4).
- Website merge (Kalvert/NJ/David) → shares codebase + studio with app content.
- Platform access (Daniel) → ✅ all cleared 1–7 Sep (GitHub, AWS, Supabase, Cloudflare/R2).

## Catalogue facts (reconciled)

- Sermon catalogue: 1,481 (API probe 31 Jul) → 1,483 (19 Aug) — growing.
- In-app video **does** count toward YouTube viewership (youtube_player_iframe).
- Playlists exist; discoverability is the issue (BACKLOG §8).
- Branch map gaps + catalogue coverage = CMS/data-side, not app bugs.

## ⏳ Pending inputs from other teams

- Web team chat/detail (beyond what surfaced in the app-team chat)
- Design workstream (DESIGN-BRIEF.md exists; no chat context yet)
- Comms/admin + content/CMS team context
- Anything from the backend/`admin` portal side not covered above

*Related docs: PRODUCT.md · docs/BUG-TRACKER.md · docs/ACTION-ITEMS.md ·
docs/BACKLOG.md · docs/INTEGRATION_ISSUES.md · docs/CONTENT-STUDIO-CONSOLIDATION.md*
