# Kharis App — Integration Issues & Evidence Log

Running log of integration/deployment issues with evidence, for reporting back
to the relevant owners. Newest section first.

---

## 1. Sermon Public API (`yetanothersermon.host/_/kc/public-api/v1`)

First probed 2026-07-31; re-verified live 2026-10-03 (all numbers below are
from the 2026-10-03 run).

### Catalogue shape

- `GET /sermons/` returns `{count, next, previous, results}`, 50 per page.
  `count` is **1,489**: pages 1 to 30 (page 30 holds 39), `?page=31` is **404**.
  `?page_size=N` is honoured for the page length but not for `count`.
- Content spans 2013 to Sep 2026. Per year: 2013:35, 2014:74, 2015:107,
  2016:52, 2017:50, 2018:54, 2019:64, 2020:161, 2021:234, 2022:165,
  2023:130, 2024:137, 2025:162, 2026:64.
- 1,484 have `audio_link`, 179 have `video_link`, 617 belong to a series (49
  distinct), 872 have no series. No sermon carries a playlist membership.
- `GET /sermons` (no trailing slash) is a **301** to `/sermons/`.
- `GET /playlists/{id}/` and `GET /series/{id}/` return metadata only
  (`{id, name, description, image_url}`), **no sermons list**.

Each sermon carries:
`audio_link, date, description, id, image, passages, preachers, series {id,name,url}, time, title, video_link, playlist (nullable)`.

### P0: `?series=` / `?playlist=` query filters are ignored server-side

Both return the entire catalogue, so the app cannot ask the server for
"sermons in series X".

```
GET /sermons/?page_size=1                -> {"count":1489}
GET /sermons/?series=1829&page_size=1    -> {"count":1489}   (filter ignored)
GET /sermons/?playlist=6&page_size=1     -> {"count":1489}   (filter ignored)
```

Impact: series and playlist pages must be built client-side by matching
`sermon.series.id` / name across the **whole** catalogue, which means paging
all 30 pages. Anything that only looks at the first pages shows incomplete
series and misses older messages.

Requested fix (server): make `?series=<id>` and `?playlist=<id>` filter, or
include `sermon_ids` in `/series/{id}/` and `/playlists/{id}/`, and populate
`playlist` on sermons.

### P1: no CORS headers

Neither a `GET` with an `Origin` header nor an `OPTIONS` preflight returns any
`Access-Control-Allow-*` header:

```
curl -H 'Origin: https://kharis-app-47c49.web.app' .../sermons/       -> 200, no Access-Control-Allow-Origin
curl -X OPTIONS -H 'Origin: ...' -H 'Access-Control-Request-Method: GET' .../sermons/ -> 200, no Access-Control-* headers
```

Impact: browsers block the response, so the web build cannot call the API
directly. The app routes web reads through the `sermonApiProxy` Cloud Function
(`ApiConfig.sermonApiBase`), which adds CORS headers and rewrites `next` links.
Mobile builds call the API directly.

Requested fix (server): send `Access-Control-Allow-Origin: *` (read-only
public API) so the proxy hop can be dropped.

### P1: scheme-less URLs

`audio_link.download_url`, `series.url` and `preachers[].url` come without a
scheme, e.g. `yetanothersermon.host/_/kc/media/mp3/99934.mp3`, while `image`
is fully qualified (`https://yash.b-cdn.net/...`). The app prepends
`https://`. Requested fix: return absolute `https://` URLs everywhere.

### P2: User-Agent filtering (not reproducible on 2026-10-03)

On 2026-07-31 Cloudflare answered **403** to non-browser User-Agents. On
2026-10-03 `Dart/3.12 (dart:io)`, `python-requests` and an empty User-Agent
all got **200**. The app keeps sending a browser User-Agent so a re-enabled
rule cannot break it.

---

## 2. Backend deploy environment (agent sandbox) — 2026-07-30

The agent's shell/network can reach some Google APIs but **not others**, which
changed how the Announcements backend had to be deployed.

### 🔴 `firebase.googleapis.com` is unreachable → `firebase deploy` fails
```
curl https://firebase.googleapis.com/... -> curl (7) Failed to connect ... port 443 after 3 ms: Couldn't connect to server   (HTTP 000)
curl https://cloudfunctions.googleapis.com/... -> HTTP 200
firebase deploy --only functions -> Error: Failed to make request to https://firebase.googleapis.com/v1beta1/projects/kharis-church/adminSdkConfig (FetchError)
```
Workaround: deployed Cloud Functions via **gcloud** (`gcloud functions deploy`)
instead of `firebase deploy`. If deploying from a normal network, `firebase
deploy` is preferred (it also wires Firestore→Eventarc triggers correctly).

### 🔴 `logging.googleapis.com` unreachable → no `gcloud functions logs`
```
gcloud functions logs read ... -> ConnectionError: logging.googleapis.com:443 ... Connection refused
```
Workaround: verified functions via observable Firestore write-backs
(`pushedAt`/`pushTopic`) instead of logs.

### 🔴 Firestore→Eventarc trigger never delivered when deployed via gcloud
`onNewsCreated` (a `google.cloud.firestore.document.v1.created` trigger)
deployed `ACTIVE` and the Eventarc trigger existed, but the function was **never
invoked** (an unconditional entry-marker write never appeared after 5 tests,
all IAM + service agents granted). This is wiring that `firebase deploy`
normally handles. Replaced with a scheduled poll — `pushPendingAnnouncements`
is now an `onSchedule` function (`every 1 minutes`), matching the `syncYouTube`
/ `syncSoundCloud` pattern, so Cloud Scheduler wiring comes from the function
definition rather than a hand-created HTTP job.

### 🟡 Kharis App (org) project not usable by the automation account
Goal was to migrate the backend to the org-owned `kharis-app-47c49`. Blocked:
```
gcloud billing projects link kharis-app-47c49 ...  -> IAM_PERMISSION_DENIED (resourcemanager.projects.deleteBillingAssignment)
gcloud services enable firestore.googleapis.com --project kharis-app-47c49 -> AUTH_PERMISSION_DENIED (serviceusage)
ayoinc@gmail.com roles on kharis-app-47c49 -> roles/firebase.admin (only)   # no billing / serviceusage
```
`kharis-app-47c49` is on the **Spark** plan (no billing linked). To use it: an
**org admin** must link a billing account (Blaze) and grant Owner (or
Billing + Service Usage Admin) to the deploying account. Stayed on
`kharis-church` (personal, ayoinc = Owner, already Blaze) for now.

**Resolved since:** everything (Firestore, Auth, FCM, Functions, Hosting) now
runs in `kharis-app-47c49`; every deploy path (`deploy-backend.yml`,
`app/scripts/build-web.sh`, BUILD.md) passes `--project kharis-app-47c49`.
