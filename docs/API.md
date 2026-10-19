# Kharis API reference

Every remote surface the Flutter app (`app/`) reads from or writes to. Content (branches, services, venues, events, announcements, featured videos, live) is managed in the Kharis Content Studio (https://kharis-content.itadmin-a94.workers.dev, Supabase). This repo has no Studio of its own and no admin roles; pushes composed in a Studio are not available until the Content Studio supports them.

Related documents:

- [`openapi.yaml`](openapi.yaml) is the OpenAPI 3.1 description of the HTTP endpoints in sections 1 to 3.
- [`MOBILE-INTEGRATION.md`](MOBILE-INTEGRATION.md) maps each app repository and provider to the endpoints and collections below, and covers timeouts, fallbacks, caching and testing.

Terminology: a church location is a **Branch**. Stored data keeps its original names. That includes the `branch` field, FCM topic ids, and code identifiers such as `CampusVenue`.

Where examples come from:

- **Live**: captured with read-only `curl` against production on 2026-10-05. Long arrays are trimmed and marked `…`.
- **Code**: built from the source file named next to the example.

Contents

1. [Cloud Functions (HTTP)](#1-cloud-functions-http)
2. [Public sermon API (yetanothersermon.host)](#2-public-sermon-api-yetanothersermonhost)
3. [Media engine: Cloudflare import Worker and R2 bucket](#3-media-engine-cloudflare-import-worker-and-r2-bucket)
4. [YouTube Data API](#4-youtube-data-api)
5. [Cloud Functions (schedulers and Firestore triggers)](#5-cloud-functions-schedulers-and-firestore-triggers)
6. [Firestore collections](#6-firestore-collections)
7. [Push notifications](#7-push-notifications)
8. [Ops: R2 bucket CORS](#8-ops-r2-bucket-cors)
9. [Function inventory](#9-function-inventory)

---

## 1. Cloud Functions (HTTP)

Firebase project `kharis-app-47c49`. The source is in `backend/functions/src`, and every function is exported from `index.ts`.

The base URL comes from `app/lib/core/constants/api_config.dart` (`ApiConfig`):

```
https://us-central1-kharis-app-47c49.cloudfunctions.net
```

Behaviour shared by the read endpoints (`getAnnouncements`, `getBranches`, `getEvents`, `getDailyReading`):

- Load limits: these endpoints and `sermonApiProxy` need no auth, so each is capped at `maxInstances: 10`. The `Cache-Control` headers are not honoured by any CDN (nothing routes the functions through Firebase Hosting), so every warm instance also keeps an in-memory copy of each response for the same TTL as its `max-age` (`getAnnouncements`: 30 seconds; `getDailyReading` is not cached in memory). Code: `response-cache.ts`.
- `GET` only. Any other method returns `405 {"error":"Method Not Allowed"}`.
- No authentication.
- CORS is open (`cors: true`), so the response echoes the request origin and carries `vary: Origin`.
- Timestamps are ISO 8601 UTC strings, except in `getBranches`, which returns document fields verbatim (see below).
- Each response also includes `count`, the length of the returned array.
- Unhandled errors (for example, Firestore unavailable) surface as the platform's default `500`. These functions define no JSON error body for that case.

### 1.1 GET /getAnnouncements

Returns live announcements from the `news` collection, newest first. An announcement is live when `publishedAt <= now` and it either has no `expiresAt` or `expiresAt > now`. Source: `index.ts`, `announcements.ts`.

| Query param | Type | Default | Notes |
|---|---|---|---|
| `branch` | string (Branch **name**, e.g. `London`) | none | When set, returns that Branch's announcements **plus** church-wide ones (`branch` null, blank or absent). Branch-scoped items are picked first and the page is then re-sorted by date. Without it, returns every Branch's announcements. |
| `limit` | int | 20 | Capped at 50. |

Caching: no `Cache-Control` header is set. Clients poll it, and push taps trigger a refetch.

Response (`AnnouncementJson`, code: `announcements.ts`):

```json
{
  "announcements": [
    {
      "id": "Xa12…",
      "title": "Baptism Sunday",
      "body": "Speak to the welcome team after the service.",
      "type": "Announcement",
      "branch": "London",
      "imageUrl": null,
      "publishedAt": "2026-10-04T08:00:00.000Z",
      "expiresAt": null,
      "eventId": null,
      "linkUrl": "https://kharis.org/baptism",
      "ctaLabel": "Learn more"
    }
  ],
  "count": 1,
  "timestamp": "2026-10-05T22:02:47.278Z"
}
```

Field notes:

- `type` is never `Event`. Legacy docs typed `Event` are served as `Announcement`.
- `ctaLabel` defaults to `Learn more` when `linkUrl` is set, and is `null` when there is no link.
- `expiresAt: null` means the announcement never expires.

Live response on 2026-10-05 (nothing was live at the time): `{"announcements":[],"count":0,"timestamp":"2026-10-05T22:02:47.278Z"}`.

### 1.2 GET /getBranches

Returns every `branches` document ordered by `order` ascending. The document fields are returned verbatim, with the doc id added as `id`.

- No query params.
- Caching: `Cache-Control: public, max-age=300`.

Firestore `Timestamp` fields such as `updatedAt` and `createdAt` come back in the Admin SDK's JSON form, `{"_seconds": n, "_nanoseconds": n}`. They are not ISO strings. Clients ignore these fields.

Live example (one Branch fully shown, the rest trimmed):

```json
{
  "branches": [
    {
      "id": "london-hq",
      "group": "Kharis",
      "name": "London",
      "subtitle": "United Kingdom · Main Campus",
      "order": 0,
      "isActive": true,
      "meetingDays": "Sundays",
      "meetingTime": "10:00 AM",
      "address": "Kensington Town Hall, Hornton St, London W8 7NX, United Kingdom",
      "imageUrl": "assets/design/city-london-hq.jpg",
      "gradientStart": "#3B2A6B",
      "gradientEnd": "#7C3AED",
      "branding": { "gradientStart": "#3B2A6B", "gradientEnd": "#7C3AED" },
      "instagram": "",
      "contact": { "email": "", "phone": "" },
      "description": "test ",
      "shortDescription": "test",
      "hero": { "subtitle": "Test", "imageUrl": "assets/design/city-london-hq.jpg" },
      "featuredVideo": { "title": "Photo", "youtubeUrl": "https://www.youtube.com/watch?v=El1RpnRYA30", "thumbnailUrl": "" },
      "venues": [
        {
          "id": "main", "name": "London Venue",
          "addressLine1": "Kensington Town Hall, Hornton St, London W8 7NX", "addressLine2": "",
          "city": "", "postcode": "", "country": "United Kingdom",
          "latitude": null, "longitude": null,
          "parkingInfo": "teset oark", "publicTransportInfo": "bus", "directionsText": "ask"
        }
      ],
      "services": [
        {
          "id": "main-service", "name": "Sunday Service", "type": "sunday", "day": "Sundays",
          "startTime": "10:00 AM", "endTime": "12:00", "venueId": "main",
          "description": "", "order": 1, "isActive": true
        }
      ],
      "pastor": { "name": "Rev Dr David Antwi", "imageUrl": "", "bio": "the best pastor ever" },
      "galleryImages": [ { "imageUrl": "", "alt": "", "order": 1 } ],
      "updatedAt": { "_seconds": 1788190536, "_nanoseconds": 248000000 }
    },
    { "id": "birmingham", "group": "Kharis", "name": "Birmingham", "order": 1, "subtitle": "…", "imageUrl": "…", "gradientStart": "…", "gradientEnd": "…" }
  ],
  "count": 24
}
```

The live data is test data entered in the Studio and is reproduced as-is.

Branch docs vary: older Branches carry only the identity fields. See [6.2](#62-branches) for the full shape.

### 1.3 GET /getEvents

Returns events from the `events` collection. Source: `index.ts`, `events-api.ts`.

| Query param | Type | Default | Notes |
|---|---|---|---|
| `branch` | string (Branch name) | none | That Branch's events plus church-wide events (`branch` null, blank or absent). Without it, returns every Branch's events. |
| `when` | `upcoming` \| `past` | `upcoming` | `upcoming`: not yet finished, soonest first. `past`: finished, most recent first. |
| `limit` | int | 50 (upcoming), 15 (past) | Capped at the default: 50 for upcoming, 15 for past. The past view is never more than the 15 most recent events. |

Rules:

- An event's effective end is `endTime`, or `startTime` when there is no end.
- Upcoming means the effective end is at or after now. The query reaches back 2 days (`IN_PROGRESS_LOOKBACK_MS`), so an event that is running stays listed.
- Docs with `hidden: true` are never returned. These are tombstones of deleted website events.

Caching: `Cache-Control: public, max-age=300` for upcoming and `public, max-age=60` for past.

Response (`EventJson`), live, `?when=past&limit=1`:

```json
{
  "events": [
    {
      "id": "aug-2026-kp2-revival",
      "title": "KP2 Youth Revival",
      "description": "Kharis Phase Two - a revival night for young people.",
      "location": "Kensington Town Hall, London",
      "branch": null,
      "imageUrl": null,
      "isFeatured": true,
      "startTime": "2026-08-29T16:00:00.000Z",
      "endTime": "2026-08-29T19:00:00.000Z"
    }
  ],
  "count": 1
}
```

`EventJson` also has `address` (string or null). The deployed function predates that field, and live responses omit it until the next deploy.

### 1.4 GET /getDailyReading

Resolves the Bible reading for a date. Resolution order (`reading-plans.ts`):

1. `dailyContent/{YYYY-MM-DD}`, a reading written by hand for that date. It always wins.
2. The covering `readingPlans` doc. When several plans cover the date, the most recently started plan wins.
3. If no plan covers the date, the plan that ended most recently is pinned to its last day.

| Query param | Type | Default | Notes |
|---|---|---|---|
| `date` | `YYYY-MM-DD` | today in Europe/London | |
| `month` | `YYYY-MM` | none | Returns every resolvable reading in that month, date ascending. Takes precedence over `date`. |

- Caching: `Cache-Control: public, max-age=300`.
- Errors: `400 {"error":"date must be YYYY-MM-DD"}` or `400 {"error":"month must be YYYY-MM"}` (live).

Live response:

```json
{
  "readings": [
    {
      "date": "2026-10-05",
      "reading": { "book": "2 Corinthians", "chapter": 19, "verse": "1-end" },
      "prayer": "Lord, speak to us through 2 Corinthians 19 today.",
      "prayerReference": "2 Corinthians 19",
      "source": "plan",
      "planId": "MlCzng0YB8ZqbIvLzVK4",
      "planTitle": "September - part 2"
    }
  ],
  "count": 1
}
```

Field notes:

- `source` is one of `day`, `plan` or `plan-last-day`. `planId` and `planTitle` are `null` for `day`.
- The current source also returns `planDay` and `planDays` (for example "Day 3 of 13"; both `null` for a `day` reading). The deployed build predates these fields.
- The chapter shown in the live response is what production currently resolves for this plan.

### 1.5 GET /sermonApiProxy/{resource}/

A CORS proxy that lets web builds reach the public sermon API ([section 2](#2-public-sermon-api-yetanothersermonhost)). Source: `sermon-proxy.ts`. Native builds call the upstream directly.

`ApiConfig.sermonApiBase` picks the base URL: `kIsWeb ? sermonApiProxyBase : sermonApiDirectBase`.

- Paths: only `sermons/`, `series/` and `playlists/` are forwarded, plus their sub-resources such as `sermons/123/`. Paths must end with `/`. Anything else returns `404 {"error":"Only sermons/, series/ and playlists/ are proxied"}`.
- Methods: GET only (`405` otherwise).
- Query string: forwarded verbatim (`page`, `search`).
- Upstream request: sent with a desktop Chrome `User-Agent`.
- Links: absolute upstream URLs in the body (`next`, `previous`) are rewritten to the proxy base, so following `next` stays on the proxy.
- CORS: limited to an allow-list of origins:
  - `https://kharis-app-47c49.web.app` and `.firebaseapp.com`
  - `http://localhost:*` and `http://127.0.0.1:*`
- Caching: `Cache-Control: public, max-age=300` on upstream 2xx responses. Upstream errors are passed through with `no-store`.
- Errors: when the upstream fetch throws, the proxy returns `502 {"error":"Upstream fetch failed: <message>"}`.
- The response body has the same shape as [2.1](#21-get-sermons).

Deployment status on 2026-10-05: `GET /sermonApiProxy/sermons/?page=2` returned Google's HTML `404 Page not found`, which means the function is not deployed yet. Until it is, web builds cannot reach the sermon API, and the Messages tab on web shows the bundled archive.

---

## 2. Public sermon API (yetanothersermon.host)

The church's sermon host. It is read-only, needs no auth, and is not run by Kharis.

```
https://yetanothersermon.host/_/kc/public-api/v1/
```

Used by:

- `app/lib/features/messages/data/kharis_api_sermon_repository.dart`, directly on mobile and through `sermonApiProxy` on web.
- The Cloudflare import Worker ([section 3](#3-media-engine-cloudflare-import-worker-and-r2-bucket)).

Requirements and quirks:

- **User-Agent.** The host sits behind Cloudflare bot protection. `http_constants.dart` documents that non-browser agents (Dio's default) get `403`, so native clients send `kBrowserUserAgent` (an iPhone Safari UA) on every API and audio request. In a live check on 2026-10-05, the API also answered `200` to curl's agent and to `Dart/3.5 (dart:io)`. Keep sending the browser UA anyway, because the protection level can change.
- **No CORS.** The live response carries no `Access-Control-*` headers even when an `Origin` is sent. Browsers must use `sermonApiProxy`.
- **Scheme-less URLs.** `audio_link.download_url` and `preachers[].url` have no scheme, for example `yetanothersermon.host/_/kc/media/mp3/99934.mp3`. Clients prepend `https://`. `next` links do carry a scheme.
- **Audio redirect.** `GET https://yetanothersermon.host/_/kc/media/mp3/<id>.mp3` answers `302`. The `Location` is a time-limited signed Cloudflare R2 URL with `X-Amz-Expires=5400`, which is 90 minutes. Players must follow redirects with the same UA, and must not cache the signed URL beyond its expiry.
- **Ignored filters.** `series` and `preacher` query filters are ignored server-side. The app filters by series and topic on the client.

### 2.1 GET sermons/

| Query param | Notes |
|---|---|
| `page` | 1-based. The page size is fixed at 50. |
| `search` | Full-text search. `next` carries it forward, e.g. `?page=2&search=grace`. |

Pagination follows the Django REST style. Walk `next` until it is `null`. `count` is the total.

Live response (first record of 50 shown):

```json
{
  "count": 1489,
  "next": "https://yetanothersermon.host/_/kc/public-api/v1/sermons/?page=2",
  "previous": null,
  "results": [
    {
      "id": 101897,
      "title": "Christ: The Eternally Blessed God",
      "time": null,
      "date": "2026-09-27",
      "passages": ["1 Timothy 3:16"],
      "series": null,
      "preachers": [
        { "id": 1880, "name": "David Antwi", "url": "yetanothersermon.host/_/kc/preachers/1880/david-antwi/", "bio": null, "image_id": null }
      ],
      "audio_link": {
        "id": 99934,
        "duration": 2945,
        "filesize": 47138066,
        "download_url": "yetanothersermon.host/_/kc/media/mp3/99934.mp3",
        "name": "e7574957-…_71dvhpb.mp3",
        "mp3_etag": null
      },
      "video_link": "https://www.youtube.com/watch?v=VdGcMD4Rwy8&t=487s",
      "image": "https://yash.b-cdn.net/media/images/Kharis_resized_H6Mr63b.jpeg?width=256",
      "image_id": null,
      "podcast_artwork_id": null,
      "description": "Christianity is often shrouded in mysticism, …",
      "transcription_id": 96162,
      "attachments": [],
      "tags": ["David Antwi", "Kharis Church", "PDAK"],
      "meeting_type": "Sunday Morning",
      "bible_version": null
    }
  ]
}
```

A search on 2026-10-05, `?search=grace`, returned `count: 55` with `next: …/sermons/?page=2&search=grace`.

How the app maps a record (`mapApiSermon`):

| Sermon field | Source |
|---|---|
| `id` | `id` as a string |
| `speaker` | `preachers[].name` joined with `, ` |
| `audioUrl` | `https://` + `audio_link.download_url` |
| `duration` | `audio_link.duration` (seconds) |
| `publishedAt` | `date` (+ `time`) |
| `artworkUrl` | `image`, with `?width=256` bumped to `512` |
| `videoId` / `videoStart` | parsed from `video_link` (`watch?v=`, `youtu.be`, `/live/`, `/shorts/`, `t=`) |
| `category` | derived from title and description, client-side |

### 2.2 GET series/ and GET playlists/

Both use the same `count/next/previous/results` envelope.

- `series` records carry `id` and `name` (or `title`).
- The playlist record shape is not confirmed. The Worker accepts `sermons` or `items`.

The app does not call either endpoint directly. They feed the Worker.

---

## 3. Media engine: Cloudflare import Worker and R2 bucket

Jonathan's media engine. The source is in `backend/cloudflare-worker/`; `src/index.js` is the only worker. It mirrors the sermon API into a public R2 bucket and adds the data that only exists on the sermon web pages: tags, related messages and transcripts.

### 3.1 Import Worker

| | |
|---|---|
| Worker name | `kharis-import-worker` (`wrangler.toml`) |
| Schedule | cron `0 6 * * 1,4`: Monday and Thursday, 06:00 UTC |
| R2 binding | `MESSAGES_BUCKET` → bucket `kharis-messages` |
| Vars | `SCRAPE_CONCURRENCY` (default `6`) |
| Secret | `MANUAL_TRIGGER_SECRET` |
| Manual run | `GET https://kharis-import-worker.<subdomain>.workers.dev/run-import?secret=<secret>`. Returns `401 Unauthorized` without the secret, `404` on any other path, a JSON summary `{messagesCount, playlistsCount, scrapedThisRun, reusedFromCache, log[]}` on success, and `500 Import failed: …` on failure. |

What one run does:

1. Walks `series/`, `sermons/` and `playlists/` on the sermon API, following `next` until `null`. A failure on series or playlists is logged and skipped. A failure on sermons aborts the run.
2. Maps each sermon to the flat `messages.json` schema ([3.2](#32-messagesjson)). Scheme-less audio URLs become `https://…`.
3. Computes `previous_id` and `next_id` within each series, ordered oldest first by `date_preached`. Sermons with no series form one group. Two sermons in the same series with the same date are logged as ambiguous.
4. For each sermon not already in `_cache/detail-cache.json`, fetches `https://yetanothersermon.host/_/kc/sermons/<id>/` and scrapes:
   - the Tags block
   - the Related Messages ids
   - the transcript `.txt` link, whose transcript id differs from the sermon id
   It then writes the transcript text, starting at the first `[m:ss]` timestamp, to `transcripts/<sermonId>.txt`.
5. Writes `_cache/detail-cache.json`, `messages.json` and `playlists.json`. Both JSON catalogue files are written with `Cache-Control: public, max-age=300`.

### 3.2 messages.json

Public URL (`kR2MessagesUrl` in `app/lib/core/constants/http_constants.dart`):

```
https://pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev/messages.json
```

Live headers on 2026-10-05:

- `200`, `Content-Type: application/json`, `Content-Length: 1487658` (about 1.5 MB)
- `Cache-Control: public, max-age=300`, with `ETag` and `Last-Modified: Sun, 04 Oct 2026 06:01:53 GMT`
- **No `Access-Control-Allow-Origin` header**, even with an `Origin` request header. See [section 8](#8-ops-r2-bucket-cors).

The file held 1,489 messages, matching the API count. Live record:

```json
{
  "messages": [
    {
      "id": "101897",
      "external_id": "101897",
      "title": "Christ: The Eternally Blessed God",
      "speaker": "David Antwi",
      "date_preached": "2026-09-27",
      "series": null,
      "topics": [],
      "keywords": [],
      "scripture_refs": ["1 Timothy 3:16"],
      "audio_url": "https://yetanothersermon.host/_/kc/media/mp3/99934.mp3",
      "image_url": "https://yash.b-cdn.net/media/images/Kharis_resized_H6Mr63b.jpeg?width=256",
      "duration": 2945,
      "description": "Christianity is often shrouded in mysticism, …",
      "transcript_available": true,
      "video_url": "https://www.youtube.com/watch?v=VdGcMD4Rwy8&t=487s",
      "tags": ["PDAK", "Kharis Church", "David Antwi"],
      "related_message_ids": ["100220", "100239", "100513", "101138", "101139"],
      "transcript_url": "transcripts/101897.txt",
      "previous_id": "101139",
      "next_id": null
    }
  ]
}
```

Schema (from `mapSermon` in `src/index.js`):

| Field | Type | Notes |
|---|---|---|
| `id`, `external_id` | string | The sermon API id |
| `title`, `speaker` | string \| null | `speaker` is the first preacher |
| `date_preached` | `YYYY-MM-DD` \| null | |
| `series` | `{id: string, name: string\|null}` \| null | |
| `topics`, `keywords` | string[] | Always empty today |
| `scripture_refs` | string[] | The API's `passages` |
| `audio_url` | string \| null | Absolute. It 302-redirects like the API URL does. |
| `image_url` | string \| null | |
| `duration` | int \| null | Seconds |
| `description` | string \| null | |
| `video_url` | string \| null | YouTube link, may carry `t=` |
| `tags` | string[] | Scraped |
| `related_message_ids` | string[] | Scraped. Excludes the sermon's own id. |
| `transcript_available` | bool | |
| `transcript_url` | string \| null | **Relative to the bucket**, e.g. `transcripts/101897.txt` |
| `previous_id`, `next_id` | string \| null | Order within the series |

### 3.3 transcripts/{id}.txt and playlists.json

`transcripts/<sermonId>.txt`:

- Served as `text/plain; charset=utf-8`, with no CORS headers.
- The text is machine-generated, with `[m:ss]` timestamps.
- Live sample: `[0:00] Welcome and thank you for joining this message by …`.

`playlists.json` has the shape `{"playlists": [{"id": "6", "title": "Catch The Glory Messages", "message_ids": []}, …]}` (live). The `message_ids` lists are currently empty. The app does not read this file.

`_cache/detail-cache.json` is the Worker's private scrape cache. It is publicly readable on the bucket, but it is not an API.

### 3.4 How the app merges R2 with the API

`R2MessagesRepository` (`app/lib/features/messages/data/r2_messages_repository.dart`) is the app's sermon repository (`sermonRepositoryProvider`).

Page 1 (no `url`, no `search`):

1. Starts the API page-1 request (`KharisApiSermonRepository.fetchPage()`) and the `messages.json` download in parallel.
2. Mirror download limits:
   - Dio `connectTimeout` 10 s
   - per-request `receiveTimeout` 20 s
   - an overall `mirrorDeadline` of **25 s** on the whole download and parse
3. When the mirror arrives with at least one record, the result is:
   - the API's page-1 records first, each given R2's `transcriptUrl` when R2 has one
   - then every mirror record not already listed
   This is returned as a single page with `nextUrl = null` and `totalCount` set to the merged length.
4. When the mirror fails, times out, is empty or is malformed, page 1 falls back to the sermon API. The app awaits the API head request (or retries it) and continues the normal paged walk through `next`. On web this is always the path today, because the bucket sends no CORS headers. **Web builds therefore show no transcripts.**

Searches and `next` links always go to the API. With no network and no saved archive, the library is empty and marked offline; the Messages screen offers Retry. No sermon catalogue is bundled with the app.

Transcript URLs are resolved against `kR2BucketBaseUrl`, giving `https://pub-…r2.dev/transcripts/<id>.txt`.

---

## 4. YouTube Data API

Two callers. Both use YouTube Data API v3 at `https://www.googleapis.com/youtube/v3` and the channel `UC4l8WmdF9ivMDQHHVOdYKqQ`.

| Caller | Calls | Key | Quota per run |
|---|---|---|---|
| `syncYouTube` (scheduler, `sync-youtube.ts`) | `search?part=id,snippet&channelId=…&order=date&type=video&maxResults=50`, then `videos?part=contentDetails&id=…` | Functions param `YOUTUBE_API_KEY` (`defineString`) | 100 (search) + 1 (videos) = **101 units per hour**, about 2,424 per day |
| App `VideoRepository` (`video_repository.dart`) | `playlistItems?part=snippet,contentDetails&playlistId=UU4l8WmdF9ivMDQHHVOdYKqQ&maxResults=20`, then `videos?part=contentDetails` | build-time `YOUTUBE_API_KEY` from `env.json` | 2 units per load, per device |

The quota figures use the standard costs: `search.list` is 100 units, and `playlistItems.list` and `videos.list` are 1 unit each. The default project quota is 10,000 units per day.

The hourly sync uses about a quarter of that.

`syncYouTube` writes `sermons/yt_<videoId>` with `{merge: true}`:

- Fields: title, `speaker: "David Antwi"`, description, videoId, thumbnailUrl, duration, publishedAt, `source: "youtube"`, `type: "video"`, `playCount: 0`, createdAt, updatedAt.
- Empty values are dropped before the write.
- Because it merges, an `isFeatured` set in the Firebase console survives the sync.

The app's video fallbacks are, in order:

1. the Data API
2. the public Atom feed `https://www.youtube.com/feeds/videos.xml?channel_id=…`, fetched directly, which on web usually fails CORS
3. the embedded list `kharisVideos` in `kharis_content.dart`

The app drops videos shorter than 120 s and titles that look like Shorts or music clips.

---

## 5. Cloud Functions (schedulers and Firestore triggers)

All functions run in `us-central1` (the default region) unless noted. Times are Europe/London unless noted.

| Function | Trigger | What it does | Audience / topic | Idempotency |
|---|---|---|---|---|
| `pushPendingAnnouncements` | every 1 minute | Pushes `news` docs that became live within the last 15 minutes and have not been pushed yet. A future `publishedAt` is pushed when it arrives. Body is capped at 140 chars. Data: `{type:'announcement', newsId, branch, eventId?}` | `branchTopic(news.branch)`: `branch_<slug>` or `all` | Claims `pushLog/news_<newsId>` with `create()` before sending, so overlapping runs cannot both send; a failed send releases the claim (retried next minute) and writes `pushError`. After a good send it writes `pushedAt`, `pushTopic` and `pushMessageId` onto the news doc; if that write fails, the claim still prevents a resend. The 15-minute window stops it from sending the backlog. |
| `pushDailyReading` | cron `0 7 * * *` (07:00) | Pushes "Today's Bible reading" with the resolved reference. Data: `{type:'reading', date, reference, source}` | topic `daily_reading` | Claims `dailyReadingPushes/{date}` in a transaction before sending. A failed send records `pushError` and is not retried. |
| `pushBirthdays` | cron `0 8 * * *` (08:00) | Direct push to each user whose `dob` month-day is today and who has an `fcmToken`, found by the query `dobMMDD == 'MM-DD'` (the app writes `dobMMDD` with `dob` and backfills it on sign-in; `scripts/backfill-dob-mmdd.mjs` backfills all profiles at once). Title: "Happy birthday!" followed by a party emoji. Data: `{type:'birthday'}`. Deletes tokens that FCM reports as unregistered. | device token `users/{uid}.fcmToken` | `birthdayPushes/{date}` created with `create()`; the run is skipped if it already exists. |
| `pushServiceReminders` | every 15 minutes | One hour before each Branch's service, parsed from `meetingDays` and `meetingTime`. Branches whose schedule is ambiguous (no weekday, or several times) get no reminder. Data: `{type:'service_reminder', branchId, branch, startTime, address}` | condition `'service_reminders' in topics && '<branch topic>' in topics` | `pushLog/service_<branchId>_<YYYY-MM-DD>` |
| `onEventWritten` | Firestore `events/{eventId}` write | "New event: …" when an event is created, or "Event updated: …" when the title, time, location, address or branch changes. A Branch move also notifies the old Branch. Data: `{type:'event', eventId, branch, startTime, location}` | condition `'events' in topics && '<branch topic>' in topics` | `pushLog/<cloudEventId>_<topic>`. The claim is released if the send fails. |
| `onBranchVenueWritten` | Firestore `branches/{branchId}` update | "<Branch>: service details updated" when `address`, `meetingDays` or `meetingTime` changes. Data: `{type:'venue', branchId, branch, address, schedule}` | `branch_<slug>` | `pushLog/<cloudEventId>_<topic>` |
| `purgePushLog` | `every day 03:30` | Deletes `pushLog` markers older than 30 days, at most 10 batches of 500 per run. | none | n/a |
| `syncYouTube` | every 60 minutes (America/New_York) | Upserts the newest 50 channel uploads into `sermons/yt_<videoId>` ([section 4](#4-youtube-data-api)). | none | Deterministic doc ids plus merge |
| `syncWebsiteEvents` | every 60 minutes | Imports kharis.org events from EventON (this month plus 2 more) into `events/web_<wpId>[_<ri>][_<branchSlug>]`. Fields: title, start and end times, location, address, description, `source:'website'`, `sourceId`, `sourceUrl`, `syncedAt`. The Branch is mapped from the WordPress `event_type`. Upcoming imports that disappear from the site are deleted, except `hidden: true` tombstones and every doc of a post skipped this run (post missing from the REST API, unknown campus or unresolved `event_type`), so a transient gap cannot wipe admin overrides or resurrect an admin-deleted event. | none (its creates are not pushed by `onEventWritten`) | Doc ids derived from the WordPress id. Unchanged events are not rewritten. Admin-owned fields (`branch`, `imageUrl`, `isFeatured`) are kept. `hidden: true` tombstones are never rewritten or deleted. |

`onEventWritten` sends nothing in these cases:

- deletes
- `hidden` docs
- events without a `startTime`
- events in the past
- writes that change only cosmetic fields such as `isFeatured`, the image or the description

`onBranchVenueWritten` sends nothing for creates, deletes, renames, or a cleared venue.

---

## 6. Firestore collections

Rules: `backend/firestore.rules`.

No client writes content and there are no admin roles: content is managed in the Kharis Content Studio. Members cannot set or change their own `role`.

The Admin SDK (Cloud Functions) bypasses the rules. Anything not listed below is denied.

### 6.1 Access summary

| Collection | Read | Create / update / delete |
|---|---|---|
| `users/{uid}` | owner | Create: owner only, with `role` in `member`/`guest`/`new_here`. Update: owner, who cannot change `role`. Keys are an allowlist of what the app writes (see [6.8](#68-users)), type-checked: on create every key, on update the changed keys (so legacy keys on old profiles stay). `dob` must be `yyyy-mm-dd`, `dobMMDD` must equal `dob`'s `MM-DD`, `fcmToken` a 1..4096-char string. Delete: owner (in-app account deletion). |
| `users/{uid}/notes/{id}` | owner only (not admins) | Owner. `body` must be 1..20000 chars; `updatedAt` must be a timestamp. |
| `users/{uid}/playlists/{id}` | owner only | Owner. `name` 1..80 chars, `sermonIds` a list, `createdAt` and `updatedAt` timestamps. |
| `branches/{id}` | public | nobody (Firebase console / Admin SDK only) |
| `news/{id}` | public | nobody (`pushPendingAnnouncements` writes push fields through the Admin SDK) |
| `events/{id}` | public | nobody (`web_*` docs are written by `syncWebsiteEvents`) |
| `sermons/{id}` | public | nobody (`syncYouTube` writes `yt_*` docs) |
| `dailyContent/{YYYY-MM-DD}` | public | nobody (Firebase console) |
| `readingPlans/{id}` | public | nobody (Firebase console). A plan needs `startDate` (`YYYY-MM-DD`), a non-empty `book` and `days` 1..400 to resolve. |
| `config/{doc}` | public | nobody (Firebase console). `featured.mode` is `auto`, `pinned` or `off`. |
| `app_feedback/{uid}_{yyyymmdd}` | nobody | Create or overwrite: any signed-in user, one doc per user per UTC day (the id must be the caller's uid plus the UTC date of the write). Keys are limited to `uid, rating, comment, source, platform, createdAt`. `uid` must be the caller, `rating` an int 1..5, `comment` ≤2000 chars, `source` `prompt` or `settings`, `platform` ≤20 chars, `createdAt == request.time`. |
| `rsvps/{uid}_{eventId}` | get: owner (by id prefix). list: queries constrained to `userId == auth.uid`. | Create: signed-in user, `userId == uid`, id `{uid}_{eventId}`. Update: never. Delete: owner. |
| `pushLog`, `dailyReadingPushes` | nobody | Admin SDK only |
| `birthdayPushes` | nobody (default deny) | Admin SDK only |

The member app no longer reads `branches`, `news`, `events` or `config/live|giving|home` (6.2 to 6.5): branches with their services and venues, events, announcements and the live stream come from the Kharis Content Studio (Supabase tables `branches`, `services`, `venues`, `events`, `news`, `app_config`), as described in [MOBILE-INTEGRATION.md §1](MOBILE-INTEGRATION.md#1-repository-map). The collections below remain for the Cloud Functions that still use them.

### 6.2 branches

The doc id is a slug (e.g. `london-hq`) or an auto id. Fields as written by the Studio and the seed data (live example in [1.2](#12-getbranches)):

| Field | Type | Notes |
|---|---|---|
| `name` | string | The Branch name, and the key that news, events and FCM topics use |
| `order` | int | Sort order |
| `group` | `Kharis` \| `KP2` | |
| `isActive` | bool | |
| `subtitle`, `shortDescription`, `description` | string | The app shows `subtitle`, falling back to the others in that order |
| `imageUrl` | string | URL |
| `gradientStart`, `gradientEnd` | `#RRGGBB` | Also under `branding` |
| `address`, `meetingDays`, `meetingTime` | string | Venue summary. These drive service reminders and venue pushes. `meetingTime` is `2:00 PM` or `14:00`. |
| `contact` | `{email, phone}` | |
| `instagram` | string | |
| `venues[]` | `{id, name, addressLine1, addressLine2, city, postcode, country, latitude, longitude, parkingInfo, publicTransportInfo, directionsText}` | |
| `services[]` | `{id, name, type, day, startTime, endTime, venueId, description, order, isActive}` | |
| `hero`, `featuredVideo`, `pastor`, `galleryImages` | map / list | Written by the former web Studio |
| `updatedAt`, `createdAt` | timestamp | |

### 6.3 news

Fields: `title`, `body`, `type` (`Announcement`/`Ministry`/`Notice`/`Update`), `branch` (name or null), `imageUrl`, `publishedAt` (timestamp; a future value schedules the item), `expiresAt` (timestamp or null), `eventId`, `linkUrl`, `ctaLabel`, `createdAt`.

Server-written: `pushedAt`, `pushTopic`, `pushMessageId`, `pushError`.

### 6.4 events

Fields: `title`, `description`, `location` (venue name), `address`, `branch` (name or null), `startTime`, `endTime`, `imageUrl`, `isFeatured`, `createdAt`.

Website imports add `source: 'website'`, `sourceId`, `sourceUrl` and `syncedAt`.

A removed `web_*` doc carries `{hidden: true, hiddenAt}` instead of being deleted, so the hourly sync does not recreate it.

### 6.5 config

| Doc | Shape | Reader | Writer |
|---|---|---|---|
| `config/featured` | `{mode: 'auto'\|'pinned'\|'off', setAt}` | `CurationRepository` (missing or error → `auto`) | Firebase console |
| `config/live` | `{isLive: bool, videoId, title}` | not read by the app (live comes from the Content Studio `app_config`) | Firebase console |
| `config/giving` | `{url?, bankName?, accountName?, sortCode?, accountNumber?, swiftBic?, iban?, reference?, note?}` | not read by the app | none |
| `config/home` | `{sections: [{id, enabled}]}` | not read by the app | none |

### 6.6 readingPlans and dailyContent

`readingPlans/{id}`:

- Common fields: `{title, book, startDate: 'YYYY-MM-DD', days, mode: 'chapter'|'verse', startChapter, prayer, prayerReference}`.
- `chapter` mode adds `verses` (e.g. `1-end`).
- `verse` mode adds `startVerse` and `versesPerDay`.

`dailyContent/{YYYY-MM-DD}`: `{reading: {book, chapter, verse}, prayer, prayerReference}`.

### 6.7 sermons

- Hand-added audio (written by the former Studio): `source` is `audio` or `admin`. Fields: title, speaker, audioUrl, thumbnailUrl, artworkUrl, duration (seconds), publishedAt, series, description, category, videoId, isFeatured, createdAt.
- YouTube mirrors: `yt_<videoId>`, `source: 'youtube'` ([section 4](#4-youtube-data-api)).
- `isFeatured: true` docs feed the carousel in `pinned` mode.

### 6.8 users

| Field | Writer |
|---|---|
| `email`, `displayName`, `photoUrl`, `createdAt` | app at registration (`FirebaseAuthRepository`) |
| `role` | Set at registration (`member`/`guest`/`new_here`; a requested `admin` is downgraded to `member`). No client can change it afterwards. |
| `branch` | owner; the selected Branch name, or null for all Branches |
| `phone`, `dob` (`yyyy-MM-dd`), `dobMMDD` (`MM-dd`, written with `dob`; backfilled on hydrate for older profiles; queried by `pushBirthdays`) | owner |
| `notificationPrefs` | owner, `Map<String,bool>` |
| `fcmToken`, `fcmTokenUpdatedAt` | app (`NotificationService.syncToken`) |

**Account deletion** (More → Delete account, signed-in email members only; Apple Guideline 5.1.1(v)). `AccountDeletionService` (`app/lib/features/settings/data/account_deletion.dart`) runs, in order:

1. `reauthenticateWithCredential` with the password the member re-enters.
2. `AccountDataRepository.deleteUserData`: batched deletes of `users/{uid}/notes/*`, `users/{uid}/playlists/*` (Favorites included), `rsvps` where `userId == uid`, then `users/{uid}`. All are owner deletes under the rules.
3. Firebase Auth `currentUser.delete()`. On `requires-recent-login` the app asks for the password and retries the whole sequence, which is idempotent.
4. Clears the device's notes box and saved onboarding role and Branch, then returns to Welcome.

`app_feedback` is write-only for members (a same-day resubmission overwrites that day's doc) and is not removed.

### 6.9 rsvps, app_feedback, pushLog

- `rsvps/{uid}_{eventId}`: `{userId, eventId, branch, eventStartTime, createdAt}`.
- `app_feedback/{uid}_{yyyymmdd}`: `{uid, rating, comment, source, platform, createdAt}`, where `platform` is `web`, `iOS`, `android` and so on.
- `pushLog/{key}`: `{claimedAt, target, title, body, messageId, sentAt}`. Server only.

---

## 7. Push notifications

### 7.1 FCM topics

Server: `backend/functions/src/topics.ts`. Client: `KharisTopics` in `app/lib/core/services/notification_service.dart`. The two slug functions must stay character-identical.

| Topic | Who is subscribed | Publishers |
|---|---|---|
| `all` | every device, always | church-wide announcements |
| `branch_<slug>` | devices whose member picked that Branch. The slug is `name.toLowerCase().trim().replace(/[^a-z0-9]+/g,'-')`, e.g. `KP2 London` → `branch_kp2-london` | Branch announcements, venue changes, and the branch half of event and reminder conditions |
| `events` | the Events preference toggle | `onEventWritten` (condition with the Branch topic) |
| `service_reminders` | the Service Reminders toggle | `pushServiceReminders` (condition) |
| `daily_reading` | the Daily Reading toggle | `pushDailyReading` |

Members on "All Branches" follow no `branch_*` topic, so they only receive church-wide pushes.

### 7.2 Tap routing

The data payload's `type` selects the screen (`notificationTargetFor`):

| `type` | Opens |
|---|---|
| `announcement` / `news` | the announcement (`newsId`), and through it the promoted event |
| `event` | `/events/<eventId>` (or `/calendar`) |
| `service_reminder`, `venue` | `/home` (Branch card) |
| `reading` | `/reading` |
| `sermon` | `/messages` |
| anything else | `/home` |

### 7.3 Studio-composed pushes

Not available. Pushes composed in a Studio (the former Firebase `notifications` service with its `studio_test` topic) were removed with the old Studio; they return when the Kharis Content Studio supports them. Until then the Notifications screen lists upcoming events and live announcements, and only the automatic pushes above are sent. Devices that followed `studio_test` stay subscribed, but nothing publishes to it.

---

## 8. Ops: R2 bucket CORS

**Problem.** The public bucket `kharis-messages` (`pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev`) returns no `Access-Control-Allow-Origin` header (checked live on 2026-10-05 with `Origin: https://kharis-app-47c49.web.app`). As a result, web builds:

- cannot read `messages.json` or `transcripts/*.txt`
- fall back to the paged sermon API through `sermonApiProxy`
- show no transcripts

Native builds are unaffected.

**Fix (bucket owner, Cloudflare account with the bucket).** Create `cors.json`. The Wrangler format comes from [Cloudflare's R2 CORS docs](https://developers.cloudflare.com/r2/buckets/cors/).

Origins:

- the hosted app (`app/firebase.json`, site `kharis-app-47c49`)
- local `flutter run -d chrome` ports

Origins cannot contain a port wildcard, so list each dev port you use.

```json
{
  "rules": [
    {
      "allowed": {
        "origins": [
          "https://kharis-app-47c49.web.app",
          "https://kharis-app-47c49.firebaseapp.com",
          "http://localhost:5000",
          "http://localhost:8080",
          "http://127.0.0.1:5000"
        ],
        "methods": ["GET", "HEAD"]
      },
      "exposeHeaders": ["ETag", "Content-Length", "Last-Modified"],
      "maxAgeSeconds": 3600
    }
  ]
}
```

Apply and verify. The syntax was checked against `npx wrangler r2 bucket cors set --help` (wrangler 4.x): `set <bucket> --file <path>`, with optional `--force` to skip the confirmation prompt.

```sh
cd backend/cloudflare-worker
npx wrangler r2 bucket cors set kharis-messages --file cors.json
npx wrangler r2 bucket cors list kharis-messages
curl -sI -H 'Origin: https://kharis-app-47c49.web.app' \
  https://pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev/messages.json | grep -i access-control
```

The last command should print `access-control-allow-origin: https://kharis-app-47c49.web.app`. Propagation can take up to 30 seconds. No app change is needed: once the header is present, `R2MessagesRepository` uses the mirror on web as well, and web shows transcripts.

Related: deploy `sermonApiProxy` ([1.5](#15-get-sermonapiproxyresource)) so that web has a working API fallback.

---

## 9. Function inventory

Every export of `backend/functions/src/index.ts`:

| Export | Kind | Section |
|---|---|---|
| `getAnnouncements` | HTTP | [1.1](#11-get-getannouncements) |
| `getBranches` | HTTP | [1.2](#12-get-getbranches) |
| `getEvents` | HTTP | [1.3](#13-get-getevents) |
| `getDailyReading` | HTTP | [1.4](#14-get-getdailyreading) |
| `sermonApiProxy` | HTTP | [1.5](#15-get-sermonapiproxyresource) |
| `pushPendingAnnouncements` | scheduler | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `pushDailyReading` | scheduler | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `pushBirthdays` | scheduler | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `pushServiceReminders` | scheduler | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `purgePushLog` | scheduler | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `syncYouTube` | scheduler | [4](#4-youtube-data-api), [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `syncWebsiteEvents` | scheduler | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `onEventWritten` | Firestore trigger | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
| `onBranchVenueWritten` | Firestore trigger | [5](#5-cloud-functions-schedulers-and-firestore-triggers) |
