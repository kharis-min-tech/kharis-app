# Kharis App — Design Improvement Brief

> Compiled from: Figma audit, kharis.org design extraction, Mobbin pattern research, and the Kharis App Workflow document.

---

## Current State Assessment

**Existing Figma file:** `Kharis App (Copy)` — contains ~30 screens across two groups:
1. **Left cluster** — Spotify/SoundCloud reference screenshots (not original work)
2. **Right cluster** — Original Kharis screens: Home, Messages, Settings, Giving, Sermons, Media Player, Calendar

**Problems with the current designs:**
- Screens are flat mockups, not built from a shared component system
- No Figma auto-layout — prevents proper dev handoff
- Colours are hardcoded per screen, not tokenised
- Typography is inconsistent across screens (sizes, weights, spacing vary)
- The gold accent (`#fd7f20`) from the brand is barely used — screens lean too heavily on pure purple with no warmth
- Card layouts are basic rectangles with no visual hierarchy
- Mini player bar lacks the polish of Spotify's persistent player
- No dark mode token system (just dark backgrounds with ad-hoc text colours)

---

## Brand Colour System (Extracted + Refined)

| Token | Hex | Purpose |
|-------|-----|---------|
| `brand-purple` | `#6b34fa` | Primary brand — headers, active states, logo |
| `brand-gold` | `#fd7f20` | Accent — CTAs, highlights, progress bars, badges |
| `brand-magenta` | `#800654` | Tertiary — gradients, depth overlays |
| `surface-dark` | `#0D0D0D` | True background |
| `surface-elevated` | `#1A1A1A` | Cards, sheets, player |
| `surface-subtle` | `#252525` | Input fields, secondary surfaces |
| `text-primary` | `#FFFFFF` | Headings, primary labels |
| `text-secondary` | `#A0A0A0` | Body copy, metadata |
| `text-muted` | `#666666` | Timestamps, tertiary info |
| `success` | `#22C55E` | Live indicators, confirmations |
| `error` | `#EF4444` | Errors, destructive actions |

**Gradient system:**
```
brand-glow:    radial-gradient(circle, #6b34fa 0%, #800654 50%, #0D0D0D 100%)
card-shimmer:  linear-gradient(135deg, #1A1A1A 0%, #252525 100%)
gold-accent:   linear-gradient(90deg, #fd7f20 0%, #f5a623 100%)
```

---

## Typography System

| Scale | Size | Weight | Use |
|-------|------|--------|-----|
| Display | 32px | Bold (700) | Splash, hero text |
| H1 | 28px | Bold (700) | Screen titles |
| H2 | 22px | SemiBold (600) | Section headers |
| H3 | 18px | SemiBold (600) | Card titles, sermon names |
| Body | 16px | Regular (400) | Descriptions, content |
| Caption | 14px | Regular (400) | Metadata, timestamps |
| Overline | 12px | Medium (500) | Labels, badges, categories |

**Families:** Maven Pro (headings), DM Sans (body)

---

## Screen-by-Screen Design Direction

### 1. Splash & Onboarding

**Current:** Basic dark screen with Kharis dove logo.

**Target:** Premium, cinematic entry. The dove should feel alive — subtle glow animation, not static.

**Flow:** Splash → Role Selection → Language → Branch → Home

**Reference patterns:**
- [H&M onboarding flow](https://mobbin.com/flows/a5b413dc-9be3-49da-a0d8-a15b17ced840) — clean, minimal steps, elegant transitions
- [Lumy onboarding](https://mobbin.com/flows/90f923e1-b560-437d-a6af-558590007a66) — dark theme, location-based personalisation
- [Liven onboarding](https://mobbin.com/flows/ba9958ef-dd21-4a03-9ba1-2e5a3f5b51e3) — multi-step with account creation + preferences

**Improvements:**
- Dove logo with animated purple glow on splash (brand-glow gradient pulsing)
- Role selection: 3 large tappable cards (Member / New Here / Guest) with icons, not a list
- Branch selection: map-based picker with nearest branch highlighted (UK locations + international)
- Language selector: subtle bottom bar, not a full screen — doesn't need its own step
- Progress indicator across onboarding steps (dots or thin bar)

---

### 2. Home Dashboard

**Current:** Basic card list, no visual hierarchy, feels flat.

**Target:** A dynamic, content-rich landing that feels like opening Spotify — immediately useful.

**Reference patterns:**
- [Mindvalley home](https://mobbin.com/screens/76dd483f-5045-42fc-85b9-064684f2b813) — personal growth dashboard, dark, rich cards
- [MasterClass browse](https://mobbin.com/screens/95307add-8679-4519-b7bf-db0cc9bd59f8) — premium dark content browsing
- [Paramount+ home](https://mobbin.com/screens/7a3ec3fb-d5c4-44c0-8ef6-3a88f6a4fba1) — hero banner + horizontal scroll rows
- [Netflix browse](https://mobbin.com/screens/4af9782e-47db-4330-9c6e-5154b445f7d6) — proven content discovery layout

**Improvements:**
- Hero card at top: current/upcoming service announcement with background image, gradient overlay, gold CTA button
- Horizontal scroll sections: "Continue Listening", "Latest Sermons", "Upcoming Events"
- Sermon cards: large thumbnail, speaker name (DM Sans Caption), title (Maven Pro H3), duration badge
- Event cards: date badge (purple pill), event name, location chip
- Daily reading card: scripture snippet with "Read More" in gold
- Announcement banner: dismissible, gold left border, subtle `surface-elevated` background

---

### 3. Media Player (Full Screen)

**Current:** Basic player with album art and controls. Lacks the richness of Spotify.

**Target:** The hero screen of the entire app. Should feel immersive and premium.

**Reference patterns:**
- [Spotify now playing](https://mobbin.com/screens/210d2d81-19f4-4df5-9b05-079beaf417a9) — the gold standard: blurred artwork background, large cover, smooth seek bar
- [Spotify full player](https://mobbin.com/screens/43a707cc-5c25-4bc8-8f7a-f24852d1f59b) — lyrics view, queue access
- [Spotify player controls](https://mobbin.com/screens/54323d77-9bb6-4b8f-b8ba-35529d42f8e5) — shuffle, repeat, share
- [Waking Up player](https://mobbin.com/screens/49fb99a8-29e4-4b05-af70-21b1af14a53b) — meditation/audio, minimal, focused

**Improvements:**
- Background: blurred + darkened sermon thumbnail (like Spotify's dynamic colour extraction)
- Large rounded sermon artwork (280×280, radius-lg)
- Seek bar: gold accent line with time elapsed/remaining
- Controls: Previous / Rewind 15s / Play-Pause (large, gold ring) / Forward 15s / Next
- Speed control pill (0.5x → 2.0x)
- Bottom actions row: Notes, Share, Playlist, Queue
- Swipe down to dismiss → reveals mini player

---

### 4. Mini Player (Persistent Bar)

**Current:** Basic bar, lacks interactivity.

**Target:** Always present when audio is playing, sits above the tab bar. Tappable to expand.

**Reference patterns:**
- [Spotify mini player](https://mobbin.com/screens/96d6b3f9-7db1-48e7-b444-2682be9fff15) — compact, artwork + title + play/pause
- [Spotify mini with progress](https://mobbin.com/screens/cdeb7282-3d1b-4662-951f-6c7c1a010d11) — thin progress bar at top of mini player
- [Spotify queue mini](https://mobbin.com/screens/a846a007-3e3e-44c8-ba26-3452d610700a) — mini player with queue peek

**Improvements:**
- Height: 56px on `surface-elevated` background
- Layout: [Thumbnail 40×40] [Title + Speaker] [Play/Pause button]
- Thin gold progress bar at the very top of the mini player (2px)
- Swipe up to expand to full player
- Swipe left to dismiss / stop

---

### 5. Sermon Library & Search

**Current:** Basic list view, no discovery features.

**Target:** Content-rich browsing with multiple entry points — categories, speakers, series, playlists.

**Reference patterns:**
- [Spotify library](https://mobbin.com/screens/05495a0a-5a18-4253-aaea-f88ba572826c) — filter chips, sort options, grid/list toggle
- [Spotify playlist](https://mobbin.com/screens/c0df9404-f3cf-490a-a9ea-40abdf6f02cc) — playlist header with artwork, shuffle play
- [IDAGIO classical library](https://mobbin.com/screens/41a93359-107b-4c7e-94ec-deab0f3d32a4) — music library with composer/artist organisation
- [SoundCloud tracks](https://mobbin.com/screens/694a2582-131e-4bc2-8f8a-f7086e3a1cff) — waveform, engagement, community feel
- [Medium discover](https://mobbin.com/screens/d4d174d0-d334-4cf0-8455-f15355827909) — content categories, topic-based browsing

**Improvements:**
- Top: Search bar with recent searches
- Filter chips row: "All", "Audio", "Video", "Series", "Speakers" (scrollable, gold border when active)
- View toggle: Grid (2 columns) / List
- Sermon card (list): [Thumbnail 64×64] [Title / Speaker / Duration / Date]
- Sermon card (grid): [Large thumbnail] [Title below] [Speaker caption]
- Series grouping: collapsible sections by sermon series
- Speaker profiles: avatar + name → tap to see all sermons by that speaker

---

### 6. Playlists

**Reference patterns:**
- [Spotify playlist detail](https://mobbin.com/screens/2363add4-3caa-4df6-9c23-d970451e4504) — cover mosaic, track list, shuffle play
- [IDAGIO playlist](https://mobbin.com/screens/7f49c756-691c-4bd2-8a87-0be24c0e100e) — curated collections with descriptions

**Improvements:**
- Playlist header: 4-tile mosaic of sermon thumbnails (auto-generated)
- Playlist name, description, sermon count, total duration
- Gold "Shuffle Play" button
- Drag-to-reorder with haptic feedback
- Context menu per track: Add to Queue, Remove, Share

---

### 7. Calendar / Events

**Current:** Basic calendar view.

**Target:** Event discovery focused on upcoming services and special events.

**Reference patterns:**
- [Luma events](https://mobbin.com/screens/08cbc859-264b-4f66-ab3a-ef59bd21000a) — beautiful event cards with dates, locations, RSVPs
- [Luma event detail](https://mobbin.com/screens/85b64805-df92-4ed2-8cb3-994ba39a108a) — rich event page with map, description, attendees
- [Luma upcoming](https://mobbin.com/screens/8b8267f0-7fd4-4c93-8455-70be3ae9ede5) — chronological event list
- [Clubhouse events](https://mobbin.com/screens/a85edf6f-dfd2-4bc6-aa9d-c1800cc692ff) — upcoming events with time, topic, participants

**Improvements:**
- Default view: upcoming events list (not a calendar grid — nobody taps calendar grids)
- Event card: [Date badge in purple pill] [Event image] [Title / Location / Time]
- Branch filter at top: "All Branches" / "London" / "Birmingham" etc.
- "Add to Calendar" button per event (system calendar integration)
- Service times: always visible at top — "Sunday 10:30am · Wednesday 7pm"
- Special events get a hero card treatment (larger, with cover image)

---

### 8. Giving (WebView)

**Reference patterns:**
- [Insight Timer donation](https://mobbin.com/screens/fb5ea744-cdf0-4f43-8db6-20978ea3184d) — clean donation interface
- [Revolut send money](https://mobbin.com/screens/b140f1a3-fb24-4d8e-9abd-58c9a72c59f2) — clean amount entry

**Improvements:**
- Pre-WebView screen: Kharis-branded giving intro with Scripture quote about generosity
- Amount quick-select buttons (£10, £25, £50, £100, Custom) — these pre-fill the WebView URL params
- WebView loads the Kharis giving page with the amount pre-selected
- Loading state: skeleton screen with Kharis branding, not a blank white page
- Success return: "Thank you" screen with share option

---

### 9. Settings / More / Profile

**Reference patterns:**
- [Calm settings](https://mobbin.com/screens/2684afeb-6304-411f-b407-ced8e50a6e1d) — dark, grouped sections, clean toggles
- [Open profile](https://mobbin.com/screens/b0dcb315-d8d5-4459-8a85-51c23e891779) — minimal profile with preferences

**Improvements:**
- Profile section: avatar, name, branch, role badge
- Grouped settings: Account, Notifications, Appearance, About
- Notification toggles: per-type (services, events, daily reading)
- Branch switcher
- Language switcher
- Dark/Light mode toggle (dark is default)
- Version info, privacy policy, contact links
- Logout in red at bottom

---

### 10. Bottom Navigation

**5 tabs:** Home | Messages | Giving | Calendar | More

**Reference patterns:**
- [Insight Timer tab bar](https://mobbin.com/screens/4c95af0b-73ae-4b5d-9d4c-4a4b209e6c2d) — 5 tabs with icons and labels, dark
- [Sora tab bar](https://mobbin.com/screens/dd104352-c965-4888-bb31-133c83e096c8) — clean 5-tab navigation

**Improvements:**
- Icons: outlined when inactive, filled when active
- Active tab: icon + label in `brand-gold`, not purple (gold makes the active state pop against the purple-dominated UI)
- Badge dots for unread notifications on Home tab
- Tab bar sits below mini player when audio is playing
- Subtle top border (1px `surface-subtle`)

---

## Component Library (Required for Figma)

The designer must deliver these as reusable Figma components with auto-layout:

| Component | Variants |
|-----------|----------|
| Sermon Card | List / Grid / Featured |
| Event Card | Compact / Expanded / Hero |
| Media Mini Player | Playing / Paused |
| Full Player | Audio / Video |
| Announcement Banner | Info / Urgent / Event |
| Notes Editor | Empty / Writing / With Timestamp |
| Button | Primary (gold) / Secondary (purple outline) / Ghost / Destructive |
| Input Field | Default / Focused / Error / Disabled |
| Bottom Tab Bar | 5 tabs, active/inactive states |
| Filter Chip | Active / Inactive |
| Badge | Notification / Category / Duration |
| Avatar | Small (32) / Medium (48) / Large (80) |
| Section Header | With "See All" action / Without |
| Loading Skeleton | Card / List Item / Player |
| Empty State | No Content / Error / Offline |

---

## Design Quality Checklist

Before any screen is signed off:

- [ ] Uses only tokenised colours (no hardcoded hex)
- [ ] Typography follows the scale exactly
- [ ] All interactive elements have pressed/disabled states
- [ ] Dark mode is default; light mode variant exists
- [ ] Minimum 44×44pt touch targets
- [ ] WCAG AA contrast on all text
- [ ] Auto-layout enabled on every frame
- [ ] Component instances used (not detached copies)
- [ ] Consistent 8px grid alignment
- [ ] Edge cases handled: empty states, long text truncation, offline

---

## Key Design Files Available

All extracted from kharis.org — in `design-extract-output/`:

| File | Import Into |
|------|-------------|
| `kharis-org-figma-variables.json` | Figma Variables |
| `kharis-org-design-tokens.json` | Any token system |
| `kharis-org-variables.css` | CSS directly |
| `kharis-org-theme.js` | Flutter theme reference |
| `kharis-org-AGENT.md` | AI design prompts |
| `kharis-org-motion-tokens.json` | Animation specs |

---

## Recommended Design Apps to Study

Study these apps in the real App Store — download them, use them, feel the interactions:

| App | Why |
|-----|-----|
| **Spotify** | The primary inspiration. Player, library, playlists, mini player |
| **Waking Up** | Dark audio/meditation app. Focused, minimal, premium |
| **MasterClass** | Premium dark content browsing with rich cards |
| **Castro** | Podcast player — queue management, triage inbox |
| **Luma** | Beautiful event discovery and calendar |
| **Mindvalley** | Personal growth content dashboard |
| **Netflix** | Content discovery rows, hero banners |

---

*This brief should be shared with the UI/UX designer as the starting point. Every screen should reference the Mobbin patterns linked above before designing from scratch.*
