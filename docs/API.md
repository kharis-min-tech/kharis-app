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
5. [Cloud Functions (schedulers)](#5-cloud-functions-schedulers)
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

Behaviour shared by the read endpoints (`getAnnouncements`, `getBranches`, `getEvents`):

- Load limits: these endpoints and `sermonApiProxy` need no auth, so each is capped at `maxInstances: 10`. The `Cache-Control` headers are not honoured by any CDN (nothing routes the functions through Firebase Hosting), so every warm instance also keeps an in-memory copy of each response for the same TTL as its `max-age` (`getAnnouncements`: 30 seconds). Code: `response-cache.ts`.
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

### 1.4 GET /sermonApiProxy/{resource}/

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
| Schedule | crons `0 22 * * 0`, `0 6 * * 1,4`, `0 18 * * 1` (UTC): Sunday night, Monday morning and evening, Thursday morning |
| R2 binding | `MESSAGES_BUCKET` → bucket `kharis-messages` |
| Vars | `SCRAPE_CONCURRENCY` (default `6`), `SCRAPE_BATCH_LIMIT` (pages scraped per cron run, default `150`; about `10` on the Free plan's 50-subrequest limit), `MANUAL_SCRAPE_LIMIT` (per manual run, default `25`) |
| Secret | `MANUAL_TRIGGER_SECRET` |
| Manual run | `GET https://kharis-import-worker.<subdomain>.workers.dev/run-import` with header `Authorization: Bearer <secret>` (compared in constant time; `?secret=` is no longer accepted). Scrapes at most `MANUAL_SCRAPE_LIMIT` pages so it finishes while you wait; call again until `remainingToScrape` is `0`. Returns `401` without the secret, `404` on any other path, a JSON summary `{messagesCount, playlistsCount, scrapedThisRun, failedThisRun, remainingToScrape, reusedFromCache, written[], skipped[], log[]}` on success, and `500 Import failed: …` on failure. |

What one run does:

1. Walks `series/`, `sermons/` and `playlists/` on the sermon API, following `next` until `null` (stops with an error on a repeated `next`, a page without a `results` array, or more than 200 pages). Every fetch times out after 15 s. A failed series fetch keeps series names from the existing `messages.json`; a failed playlists fetch skips writing `playlists.json`; a failed sermons fetch aborts the run and writes nothing.
2. Maps each sermon to the flat `messages.json` schema ([3.2](#32-messagesjson)). Scheme-less audio URLs become `https://…`.
3. Computes `previous_id` and `next_id` within each series, ordered oldest first by `date_preached`. Sermons with no series form one group. Two sermons in the same series with the same date are logged as ambiguous.
4. Scrapes `https://yetanothersermon.host/_/kc/sermons/<id>/` for at most `SCRAPE_BATCH_LIMIT` sermons, in this order: sermons not yet in `_cache/detail-cache.json`; cached sermons whose `transcripts/<id>.txt` object is missing from the bucket; sermons preached in the last 30 days that still have no transcript. Newest first within each group. It extracts:
   - the Tags block
   - the Related Messages ids
   - the transcript `.txt` link, whose transcript id differs from the sermon id
   It then writes the transcript text, starting at the first `[m:ss]` timestamp, to `transcripts/<sermonId>.txt`. A failed scrape (error page, network error, timeout, failed transcript download) is not cached and is retried on the next run. The cache is saved every 25 scrapes.
5. Writes `_cache/detail-cache.json`, `messages.json` and `playlists.json`. Both JSON catalogue files are written with `Cache-Control: public, max-age=300`. A sermon whose transcript object is missing gets no `transcript_url`. A new `messages.json` that is empty or smaller than 90% of the existing one is not written; the run logs an error and keeps the old file.

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

## 5. Cloud Functions (schedulers)

All functions run in `us-central1` (the default region) unless noted. Times are Europe/London unless noted.

The Content Studio writes Supabase only, so every content push polls the Studio's tables over PostgREST (`content-studio.ts`, the same URL and publishable key as the app and `pushDailyReading`; no secrets or env vars) and keeps its bookkeeping in `push-state.ts` (claims in `pushLog`, snapshots and checkpoints in `pushState`). The senders are in `studio-pushes.ts`; the schedules in `content-notifications.ts`.

| Function | Trigger | What it does | Audience / topic | Idempotency |
|---|---|---|---|---|
| `pushPendingAnnouncements` | every 1 minute | Pushes Studio `news` rows in workspace `app` or `general` whose `published_at` is within the last 15 minutes and not in the future, and that have not expired (`expires_at` null or later). A future `published_at` is pushed when it arrives. Title: `title`; body: `body` capped at 140 chars, else "New announcement". Data: `{type:'announcement', newsId (Supabase id), branch (branch_name or ''), eventId?}` | condition `'<branch topic>' in topics && !('mute_announcements' in topics)`, the branch topic being `branch_<slug>` of `branch_name`, or `all` | Claims `pushLog/news_<id>` before sending, so overlapping runs cannot both send; a failed send releases the claim and is retried next minute. The 15-minute window stops it from sending the backlog. |
| `pushDailyReading` | cron `0 7 * * *` (07:00) | Pushes "Today's Bible reading" with today's (Europe/London) Content Studio reading, the same row the app shows: Supabase `daily_entries`, `kind=reading`, workspace `app` before `general` (`daily-reading.ts`). Body: the row's `reference`, else its `title`. No row, a missing table (404) or a failed lookup sends nothing; there is no fallback. Every passage of the body must name a book of the 66-book canon and a chapter that book has (`bible-chapters.ts`); otherwise nothing is sent and the claim records `skipped: 'invalid reference: …'`. Data: `{type:'reading', date, reference}` | topic `daily_reading_v2`, plus condition `'daily_reading' in topics && !('daily_reading_v2' in topics)` for app builds still on the legacy topic (`READING_AUDIENCES` in `topics.ts`) | Claims `dailyReadingPushes/{date}` in a transaction before the lookup. A day with no or an invalid reading records `skipped`; a failed send records `pushError` (`pushMessageId` lists the sends that succeeded). Neither is retried. |
| `pushBirthdays` | cron `0 8 * * *` (08:00) | Direct push to each user whose `dob` month-day is today and who has an `fcmToken`, found by the query `dobMMDD == 'MM-DD'` (the app writes `dobMMDD` with `dob` and backfills it on sign-in; `scripts/backfill-dob-mmdd.mjs` backfills all profiles at once). Title: "Happy birthday!" followed by a party emoji. Data: `{type:'birthday'}`. Deletes tokens that FCM reports as unregistered. | device token `users/{uid}.fcmToken` | `birthdayPushes/{date}` created with `create()`; the run is skipped if it already exists. |
| `pushServiceReminders` | every 15 minutes | One hour before each active Studio service (`services.day` and `start_time`, branches and venues joined as the app joins them). A service without a readable weekday or time gets no reminder. Body names the service's venue address. Data: `{type:'service_reminder', branchId (slug), branch, startTime, address}` | condition `'service_reminders' in topics && '<branch topic>' in topics` | `pushLog/service_<branchSlug>_<YYYY-MM-DD>_<HH:MM>` |
| `pushEventUpdates` | every 5 minutes | Polls Studio `events` rows whose `updated_at` or `created_at` is after the checkpoint `pushState/events` (less 2 minutes of overlap) and that the app shows (`sites` contains `app` or `general`) and that are not over (a weekly event: it has an upcoming occurrence before `recurrence_until`). A row created since the checkpoint: "New event: …". A row whose title, time (start, end, weekly days, `recurrence_until`), `location` or `branch_name` differs from its last pushed snapshot `pushState/event_<id>`: "Event updated: …", led by what changed. A Branch move also notifies the old Branch ("Moved to …"). Body: date (a weekly event: "Every Sunday"), time and location in London time. Data: `{type:'event', eventId (Supabase id), branch, startTime (next occurrence), location}` | condition `'events' in topics && '<branch topic>' in topics` (`all` when the event has no branch) | `pushLog/event_<id>_<updated_at ms>_<topic>`. A failed send releases its claim and holds the checkpoint, so the next poll retries. |
| `pushBranchUpdates` | every 5 minutes | "<Branch>: service details updated" when an active branch's active services change day, start time, or venue name or address, compared with `pushState/branches` (branch uuid → signature). Body: "We now meet Sundays 1:00 PM · <address>; …". Data: `{type:'venue', branchId (slug), branch, address, schedule}` | condition `'service_reminders' in topics && '<branch topic>' in topics` | `pushLog/branch_<uuid>_<old hash>_<new hash>`. A failed send keeps the old signature, so the next poll retries. |
| `purgePushLog` | `every day 03:30` | Deletes `pushLog` claims older than 30 days and `pushState` snapshots past their `keepUntil`, at most 10 batches of 500 each per run. | none | n/a |
| `syncYouTube` | every 60 minutes (America/New_York) | Upserts the newest 50 channel uploads into `sermons/yt_<videoId>` ([section 4](#4-youtube-data-api)). | none | Deterministic doc ids plus merge |
| `syncWebsiteEvents` | every 60 minutes | Imports kharis.org events from EventON (this month plus 2 more) into `events/web_<wpId>[_<ri>][_<branchSlug>]`. Fields: title, start and end times, location, address, description, `source:'website'`, `sourceId`, `sourceUrl`, `syncedAt`. The Branch is mapped from the WordPress `event_type`. Upcoming imports that disappear from the site are deleted, except `hidden: true` tombstones and every doc of a post skipped this run (post missing from the REST API, unknown campus or unresolved `event_type`), so a transient gap cannot wipe admin overrides or resurrect an admin-deleted event. | none | Doc ids derived from the WordPress id. Unchanged events are not rewritten. Admin-owned fields (`branch`, `imageUrl`, `isFeatured`) are kept. `hidden: true` tombstones are never rewritten or deleted. |

`pushEventUpdates` sends nothing for:

- deletes, and rows the app does not show (website-only `sites`, or unpublished: empty `sites`)
- events that are over
- saves that change only other fields, such as the image, the description or `is_featured`
- an event created before the checkpoint and never seen before (its snapshot is recorded instead, so its next real change is pushed)

`pushBranchUpdates` sends nothing on its first run (it only records the snapshot), for a branch seen for the first time, or for a branch whose services were all removed.

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
| `news/{id}` | public | nobody (Firebase console / Admin SDK only) |
| `events/{id}` | public | nobody (`web_*` docs are written by `syncWebsiteEvents`) |
| `sermons/{id}` | public | nobody (`syncYouTube` writes `yt_*` docs) |
| `dailyContent/{YYYY-MM-DD}` | public | nobody (Firebase console). Legacy: no longer read by the app or the functions. |
| `readingPlans/{id}` | public | nobody (Firebase console). Legacy: no longer read by the app or the functions. |
| `config/{doc}` | public | nobody (Firebase console). `featured.mode` is `auto`, `pinned` or `off`. |
| `app_feedback/{uid}_{yyyymmdd}` | nobody | Create or overwrite: any signed-in user, one doc per user per UTC day (the id must be the caller's uid plus the UTC date of the write). Keys are limited to `uid, rating, comment, source, platform, createdAt`. `uid` must be the caller, `rating` an int 1..5, `comment` ≤2000 chars, `source` `prompt` or `settings`, `platform` ≤20 chars, `createdAt == request.time`. |
| `rsvps/{uid}_{eventId}` | get: owner (by id prefix). list: queries constrained to `userId == auth.uid`. | Create: signed-in user, `userId == uid`, id `{uid}_{eventId}`. Update: never. Delete: owner. |
| `pushLog`, `pushState`, `dailyReadingPushes` | nobody | Admin SDK only |
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
| `address`, `meetingDays`, `meetingTime` | string | Venue summary. No longer read by the functions: service reminders and service-detail pushes come from the Studio's `services` and `venues` tables. |
| `contact` | `{email, phone}` | |
| `instagram` | string | |
| `venues[]` | `{id, name, addressLine1, addressLine2, city, postcode, country, latitude, longitude, parkingInfo, publicTransportInfo, directionsText}` | |
| `services[]` | `{id, name, type, day, startTime, endTime, venueId, description, order, isActive}` | |
| `hero`, `featuredVideo`, `pastor`, `galleryImages` | map / list | Written by the former web Studio |
| `updatedAt`, `createdAt` | timestamp | |

### 6.3 news

Fields: `title`, `body`, `type` (`Announcement`/`Ministry`/`Notice`/`Update`), `branch` (name or null), `imageUrl`, `publishedAt` (timestamp; a future value schedules the item), `expiresAt` (timestamp or null), `eventId`, `linkUrl`, `ctaLabel`, `createdAt`.

Server-written by the retired Firestore announcement poller: `pushedAt`, `pushTopic`, `pushMessageId`, `pushError`.

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

### 6.6 readingPlans and dailyContent (legacy)

Neither collection is read any more: today's reading comes from the Content Studio `daily_entries` table, in the app and in `pushDailyReading`. The shapes below describe the documents still stored.

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

### 6.9 rsvps, app_feedback, pushLog, pushState

- `rsvps/{uid}_{eventId}`: `{userId, eventId, branch, eventStartTime, createdAt}`.
- `app_feedback/{uid}_{yyyymmdd}`: `{uid, rating, comment, source, platform, createdAt}`, where `platform` is `web`, `iOS`, `android` and so on.
- `pushLog/{key}`: one claim per push, `{claimedAt, target, title, body, messageId, sentAt}`. Server only; purged after 30 days.
- `pushState/{key}`: `{value, savedAt, keepUntil?}`. Server only. Keys: `events` (`{checkedAt}`, the event poll's checkpoint), `event_<supabaseId>` (the last pushed title, times, weekly days, location and branch of an event; kept until a month after it ends, a year for an open-ended weekly event) and `branches` (branch uuid → service signature). Purged once `keepUntil` passes. Both collections are reached only through `push-state.ts`.

---

## 7. Push notifications

### 7.1 FCM topics

Server: `backend/functions/src/topics.ts`. Client: `KharisTopics` in `app/lib/core/services/notification_service.dart`. The two slug functions must stay character-identical.

| Topic | Who is subscribed | Publishers |
|---|---|---|
| `all` | every device, always | church-wide announcements (condition with `mute_announcements`) |
| `branch_<slug>` | devices whose member picked that Branch. The slug is `name.toLowerCase().trim().replace(/[^a-z0-9]+/g,'-')`, e.g. `KP2 London` → `branch_kp2-london` | the branch half of announcement, event, service-detail and reminder conditions |
| `mute_announcements` | opt-out: devices whose member turned the Announcements toggle off. App builds from before the toggle never join it, so they keep receiving announcements | `pushPendingAnnouncements` (condition `'<branch topic>' in topics && !('mute_announcements' in topics)`) |
| `events` | the Events preference toggle | `pushEventUpdates` (condition with the Branch topic) |
| `service_reminders` | the Service Reminders toggle | `pushServiceReminders` and `pushBranchUpdates` (condition with the Branch topic) |
| `daily_reading_v2` | the Daily Reading toggle | `pushDailyReading` |
| `daily_reading` | legacy: app builds before `daily_reading_v2`. Current builds unsubscribe from it on every launch | `pushDailyReading`, only to devices not also on `daily_reading_v2` |

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

Related: deploy `sermonApiProxy` ([1.4](#14-get-sermonapiproxyresource)) so that web has a working API fallback.

---

## 9. Function inventory

Every export of `backend/functions/src/index.ts`:

| Export | Kind | Section |
|---|---|---|
| `getAnnouncements` | HTTP | [1.1](#11-get-getannouncements) |
| `getBranches` | HTTP | [1.2](#12-get-getbranches) |
| `getEvents` | HTTP | [1.3](#13-get-getevents) |
| `sermonApiProxy` | HTTP | [1.4](#14-get-sermonapiproxyresource) |
| `pushPendingAnnouncements` | scheduler | [5](#5-cloud-functions-schedulers) |
| `pushDailyReading` | scheduler | [5](#5-cloud-functions-schedulers) |
| `pushBirthdays` | scheduler | [5](#5-cloud-functions-schedulers) |
| `pushServiceReminders` | scheduler | [5](#5-cloud-functions-schedulers) |
| `pushEventUpdates` | scheduler | [5](#5-cloud-functions-schedulers) |
| `pushBranchUpdates` | scheduler | [5](#5-cloud-functions-schedulers) |
| `purgePushLog` | scheduler | [5](#5-cloud-functions-schedulers) |
| `syncYouTube` | scheduler | [4](#4-youtube-data-api), [5](#5-cloud-functions-schedulers) |
| `syncWebsiteEvents` | scheduler | [5](#5-cloud-functions-schedulers) |

`onEventWritten` and `onBranchVenueWritten` (Firestore triggers on `events` and `branches`, which the Studio no longer writes) were replaced by `pushEventUpdates` and `pushBranchUpdates`; delete them from production with `firebase functions:delete onEventWritten onBranchVenueWritten --region us-central1`.
