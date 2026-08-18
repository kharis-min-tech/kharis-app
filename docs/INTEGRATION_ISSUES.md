# Kharis App — Integration Issues & Evidence Log

Running log of integration/deployment issues with evidence, for reporting back
to the relevant owners. Newest section first.

---

## 1. Sermon Public API (`yetanothersermon.host/_/kc/public-api/v1`)

Probed 2026-07-31. A browser `User-Agent` is required on every call (Cloudflare
returns **403** to non-browser agents — the app already sends one).

### Endpoint status (with browser UA)

| Endpoint | Result | Notes |
|---|---|---|
| `GET /sermons` | **301** | Redirects — must use trailing slash `/sermons/` (or follow redirects). |
| `GET /sermons/` | 200 | `{count: 1481, next, previous, results:[…]}`. |
| `GET /playlists/` | 200 | `{count: 9, results:[{id, name, description, image_url}]}`. |
| `GET /series/` | 200 | `{count: 52, results:[{id, name, description, image_url}]}`. |
| `GET /playlists/{id}/` | 200 | Metadata only: `{id, name, description, image_url}` — **no sermons list**. |
| `GET /series/{id}/` | 200 | Metadata only — **no sermons list**. |

Each sermon in `/sermons/` carries:
`audio_link, date, description, id, image, passages, preachers, series {id,name,url}, time, title, video_link, playlist (nullable)`.

### 🔴 P0 — `?series=` / `?playlist=` query filters are ignored server-side
Both return the **entire** catalogue (count 1481), so the app cannot ask the
server for "sermons in series X".

Evidence:
```
GET /sermons/?series=1829&page_size=3   -> {"count":1481}
GET /sermons/?playlist=6&page_size=3    -> {"count":1481}
GET /sermons/?page_size=1               -> {"count":1481}   (unfiltered, same)
```
Impact: playlist/series → sermons linkage must be done **client-side** by
matching `sermon.series.name`, over only the pages the app has fetched
(currently ~200 of 1481). A series/playlist detail is therefore **incomplete**
for older content.

Requested fix (server): make `?series=<id>` and `?playlist=<id>` actually
filter, **or** include a `sermons` array (or `sermon_ids`) in
`/series/{id}/` and `/playlists/{id}/`.

### 🟡 P1 — scheme-less URLs
`audio_link.download_url`, `series.url`, `preachers[].url` are returned without
`https://` (e.g. `yetanothersermon.host/...`); the app prepends the scheme.
Consistency would be cleaner (some fields, e.g. `image`, are fully-qualified).

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
