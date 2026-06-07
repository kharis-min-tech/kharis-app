# Kharis App — Content Sources & API Integration

## Media Sources

### 1. SoundCloud (Audio Sermons)
- **Channel:** [soundcloud.com/kharismedia](https://soundcloud.com/kharismedia)
- **User ID:** `58625221`
- **Content:** 1,469 tracks, 3,249 followers
- **Primary speaker:** Pastor David Antwi (also Awo Antwi)
- **Upload cadence:** Weekly (latest: June 2026)

**API approach:**
- SoundCloud HTTP API (`api-v2.soundcloud.com`) — no official public API anymore
- Use RSS feed as primary: `https://feeds.soundcloud.com/users/soundcloud:users:58625221/sounds.rss`
- Parse RSS for: title, description, audio URL, duration, publish date, artwork
- Cache tracks locally with position tracking for resume playback
- The audio stream URLs from SoundCloud support background playback natively

**Alternative:** SoundCloud provides oEmbed — can embed player, but native playback is better UX.

### 2. YouTube (Video Sermons)
- **Channel:** [youtube.com/KharisMinistries](https://www.youtube.com/KharisMinistries)
- **Content:** Regular sermon videos, church culture series, special events

**API approach:**
- YouTube Data API v3 — requires API key (free tier: 10,000 quota units/day)
- Endpoints needed:
  - `search` — list latest videos (cost: 100 units per call)
  - `videos` — get video details, thumbnails, duration (cost: 1 unit)
  - `playlists` — list channel playlists (cost: 1 unit)
  - `playlistItems` — list videos in a playlist (cost: 1 unit)
- Playback: Use `youtube_player_flutter` or `youtube_player_iframe` package
- **Do NOT embed YouTube's native player** — use native video player with YouTube URL extraction for premium feel

### 3. Spotify (Podcast)
- **Show:** "Messages by David Antwi"
- **URL:** [open.spotify.com/show/6EfmpLAHngHDBsLjrQwnS7](https://open.spotify.com/show/6EfmpLAHngHDBsLjrQwnS7)
- **Note:** Read-only source. Can link to Spotify but cannot play inline without Spotify SDK.

---

## Backend API Requirements

The app needs a lightweight backend (or Firebase) to serve:

| Endpoint | Data | Source |
|----------|------|--------|
| `/sermons` | Audio sermon list | SoundCloud RSS (cached) |
| `/videos` | Video sermon list | YouTube API (cached) |
| `/events` | Upcoming events | Admin CMS / Google Calendar |
| `/news` | News & updates | Admin CMS |
| `/daily-prayer` | Daily prayer content | Admin CMS |
| `/daily-reading` | Bible reading plan | Static schedule |
| `/branches` | Branch info + coordinates | Static / CMS |
| `/notifications` | Push notification config | FCM |

**Option A — Firebase (recommended for MVP):**
- Firestore for events, news, daily content
- Cloud Functions to sync SoundCloud RSS + YouTube API hourly
- Firebase Auth for iKharis login
- FCM for push notifications
- No server to manage

**Option B — Custom backend:**
- Node.js/Express or Python/FastAPI
- PostgreSQL or MongoDB
- Hosted on Railway, Render, or Fly.io
- More control, more maintenance

---

## Content Sync Strategy

```
SoundCloud RSS ──┐
                 ├──→ [Cloud Function / Cron] ──→ Firestore ──→ App
YouTube API ─────┘         (runs hourly)

Events / News ──→ [Admin Dashboard] ──→ Firestore ──→ App
```

1. Cloud function runs every hour
2. Fetches SoundCloud RSS + YouTube API
3. Deduplicates and stores in Firestore
4. App reads from Firestore (with local caching)
5. Admin dashboard for events, news, daily prayer (manual content)

---

## API Keys Required

| Service | Key Type | Where to Get |
|---------|----------|-------------|
| YouTube Data API v3 | API Key | [console.cloud.google.com](https://console.cloud.google.com) |
| Firebase | google-services.json / GoogleService-Info.plist | Firebase Console |
| SoundCloud | None needed (RSS is public) | — |
| FCM | Server key | Firebase Console |

---

## Audio Playback Architecture

```
                    ┌─────────────────────┐
                    │   Audio Service      │
                    │   (just_audio pkg)   │
                    ├─────────────────────┤
                    │ - Background play    │
                    │ - Lock screen ctrl   │
                    │ - Position tracking  │
                    │ - Queue management   │
                    │ - Speed control      │
                    └──────┬──────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         SoundCloud    Local Cache   Offline
         Stream URL    (resume pos)  Downloads
```

**Key packages:**
- `just_audio` — background playback, lock screen, speed control
- `audio_service` — system media integration (iOS + Android)
- `cached_network_image` — sermon artwork caching
- `hive` — local storage for playback position, preferences
