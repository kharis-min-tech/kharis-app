# Kharis Church — Firebase Backend Setup

## Prerequisites

- Node 18+
- Firebase CLI: `npm install -g firebase-tools`
- A Google account with access to the Firebase Console

---

## 1. Create the Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `kharis-church` (or match your bundle ID convention)
3. Disable Google Analytics if not needed, then click **Create project**

---

## 2. Enable required Firebase services

In the Firebase Console for your project:

### Firestore Database
- Navigate to **Build → Firestore Database**
- Click **Create database**
- Choose **Production mode** (rules will be deployed via CLI)
- Select a region close to your users (e.g. `us-east1` for US-based)

### Authentication
- Navigate to **Build → Authentication**
- Click **Get started**
- Enable **Email/Password** as a sign-in provider
- Optionally enable **Google** sign-in

### Cloud Functions
- Navigate to **Build → Functions**
- Click **Get started** — this enables the Functions API
- You need to be on the **Blaze (pay-as-you-go)** plan to deploy functions

---

## 3. Initialize the Firebase project locally

```bash
cd ~/Workspace/kharis-org/backend

# Log in
firebase login

# Link this directory to your Firebase project
firebase use --add
# Select your project from the list and give it an alias e.g. "default"
```

---

## 4. Set the YouTube API key

The `syncYouTube` function needs a YouTube Data API v3 key.

### Get a YouTube API key
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Select the same project linked to your Firebase project
3. Navigate to **APIs & Services → Library**
4. Search for **YouTube Data API v3** and enable it
5. Navigate to **APIs & Services → Credentials**
6. Click **Create Credentials → API key**
7. Restrict the key to **YouTube Data API v3** (recommended)

### Set it as a Cloud Functions parameter

```bash
# Using Firebase Functions params (v2 recommended approach)
# Create a .env file in functions/ for local dev:
echo "YOUTUBE_API_KEY=YOUR_KEY_HERE" > functions/.env

# For production, set it in the Firebase Console or via CLI:
firebase functions:secrets:set YOUTUBE_API_KEY
# Then enter your key when prompted
```

> **Note:** The function uses `defineString('YOUTUBE_API_KEY')` which reads from
> environment config. For local emulation, `functions/.env` is loaded automatically.
> For production, use Firebase Secrets (recommended) or `functions/.env.<project>`.

---

## 5. Install dependencies and build

```bash
cd functions
npm install
npm run build
```

---

## 6. Deploy

Deploy everything (functions + Firestore rules + indexes):

```bash
cd ~/Workspace/kharis-org/backend
firebase deploy --only functions,firestore
```

Deploy individually if needed:

```bash
# Functions only
firebase deploy --only functions

# Firestore rules only
firebase deploy --only firestore:rules

# Firestore indexes only
firebase deploy --only firestore:indexes
```

---

## 7. Admins

### Super admins

A super admin may write everything admins can write. Either set the `admin: true`
custom claim from a trusted server environment via the Firebase Admin SDK:

```typescript
import { getAuth } from 'firebase-admin/auth';

// Set admin claim for a user by UID
await getAuth().setCustomUserClaims('USER_UID_HERE', { admin: true });
```

or set `role: 'admin'` on the user's `users/{uid}` profile (Content Studio does
this; only an existing super admin can change a role).

### Branch admins

A branch admin manages only their own branches: the `news` and `events` whose
`branch` is one of their branches, and the non-identity fields of those
`branches/{id}` docs (contact, services, venues, giving, Home layout, …). They
cannot write all-branch (null/blank `branch`) items, move an item to another
branch, change a branch's `name`, `order`, `group` or `isActive`, create or
delete branches, or touch `config/*`, sermons, reading plans, daily content,
users or submissions.

A super admin assigns one by setting all three fields together on
`users/{uid}` (Content Studio's user editor does this):

| Field | Value |
|---|---|
| `role` | `'campus_admin'` |
| `adminBranchIds` | branch doc ids, e.g. `['north']` |
| `adminBranchNames` | the matching branch **names**, e.g. `['North']` — news/events store `branch` as the name |

Keep the two lists in step (and update `adminBranchNames` if a branch is
renamed). Users can never set their own `role` or branch lists.

### Testing the rules

`backend/functions/test/rules/` exercises `firestore.rules` against the
Firestore emulator (needs Java 11+ on `PATH`):

```bash
cd ~/Workspace/kharis-org/backend/functions
npm run test:rules
```

---

## 8. Add Firebase config to the Flutter app

### Android
1. In the Firebase Console → Project Settings → Your apps → Add app → Android
2. Register the package name (e.g. `com.kharis.church`)
3. Download `google-services.json`
4. Place it at `app/android/app/google-services.json`

### iOS
1. In the Firebase Console → Project Settings → Your apps → Add app → iOS
2. Register the bundle ID (e.g. `com.kharis.church`)
3. Download `GoogleService-Info.plist`
4. Open Xcode, right-click the `Runner` folder, **Add Files to "Runner"**
5. Select the downloaded `GoogleService-Info.plist`

---

## 9. Local emulation (optional)

Run the full emulator suite locally for development:

```bash
cd ~/Workspace/kharis-org/backend
firebase emulators:start
```

The emulator UI is available at [http://localhost:4000](http://localhost:4000).

### Content Studio against the emulators

`admin/index.html` connects to the Auth emulator (`127.0.0.1:9099`) and the
Firestore emulator (`127.0.0.1:8181`) under the offline project `demo-kharis`
when it is opened on localhost with `?emulators=1`. The hosted Studio ignores
the flag, so it can never be pointed away from production.

```bash
# firebase.json for the emulators: {"firestore":{"rules":"<repo>/backend/firestore.rules"},
#   "emulators":{"auth":{"port":9099},"firestore":{"port":8181},"singleProjectMode":true}}
firebase emulators:start --only auth,firestore --project demo-kharis
cd ~/Workspace/kharis-org/admin && python3 -m http.server 5055 --bind 127.0.0.1
open 'http://localhost:5055/?emulators=1'
```

The emulators start empty: create test users through the Auth emulator REST API
(`/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`) and write their
`users/{uid}` docs (role `admin` or `campus_admin` with `adminBranchIds` and
`adminBranchNames`) plus sample `branches`, `news` (`publishedAt`, `expiresAt`)
and `events` through the Firestore emulator REST API with
`Authorization: Bearer owner`, which bypasses the rules. Notifications can be
composed but are not delivered: the functions are not emulated.

---

## Firestore Schema Reference

### `sermons` collection

| Field | Type | Notes |
|---|---|---|
| `id` | string | Auto-generated doc ID |
| `title` | string | |
| `speaker` | string | Default: `'David Antwi'` |
| `description` | string | |
| `audioUrl` | string | Empty string for YouTube-only |
| `videoId` | string? | YouTube video ID (YouTube only) |
| `thumbnailUrl` | string? | |
| `duration` | number | Seconds |
| `publishedAt` | Timestamp | |
| `source` | `'soundcloud' \| 'youtube'` | |
| `type` | `'audio' \| 'video'` | |
| `series` | string? | Sermon series name |
| `category` | string? | Tag/category |
| `playCount` | number | Default 0 |
| `createdAt` | Timestamp | |
| `updatedAt` | Timestamp | |

**Deduplication keys:**
- SoundCloud: document ID = base64url(audioUrl) truncated to 64 chars
- YouTube: document ID = `yt_<videoId>`

### `events` collection

| Field | Type | Notes |
|---|---|---|
| `id` | string | Auto-generated |
| `title` | string | |
| `description` | string | |
| `location` | string | |
| `branch` | string | Church branch name |
| `startTime` | Timestamp | |
| `endTime` | Timestamp? | |
| `imageUrl` | string? | |
| `isFeatured` | boolean | |
| `createdAt` | Timestamp | |

### `dailyContent` collection

Document ID is the date string in `YYYY-MM-DD` format.

| Field | Type | Notes |
|---|---|---|
| `id` | string | Date: `'2026-06-08'` |
| `reading.book` | string | Bible book name |
| `reading.chapter` | string | Chapter number/range |
| `reading.verse` | string? | Verse reference |
| `prayer` | string | Full prayer text |
| `prayerReference` | string | Scripture reference for prayer |
| `createdAt` | Timestamp | |

### `news` collection

| Field | Type | Notes |
|---|---|---|
| `id` | string | Auto-generated |
| `title` | string | |
| `body` | string | Full article body |
| `imageUrl` | string? | |
| `publishedAt` | Timestamp | |
| `expiresAt` | Timestamp? | Auto-hide after this date |

### `branches` collection — branch customisation

Besides name, services, venues and contact details, each branch may carry:

| Field | Type | Notes |
|---|---|---|
| `giving` | map? | `{url?, bankName?, accountName?, sortCode?, accountNumber?, swiftBic?, iban?, reference?, note?}` — all strings, `url` http(s). Absent/null = church-wide `config/giving` |
| `home` | map? | `{sections: [{id, enabled}]}` — ordered Home blocks. Absent/null = `config/home` |

### `config` collection

Publicly readable; super-admin writable only.

| Doc | Shape | Notes |
|---|---|---|
| `live` | live status | |
| `featured` | `{mode: 'auto' \| 'pinned' \| 'off', setAt}` | Messages tab featured carousel; `off` hides it |
| `giving` | same as `branches.giving` | Church-wide giving details; absent = the app's built-in details |
| `home` | `{sections: [{id, enabled}]}` | Church-wide default Home layout. Section ids: `profileCompletion, live, reading, announcements, events, campus, continueListening, giving`; absent = the app's built-in order |

---

## Scheduled function schedule

| Function | Schedule | Notes |
|---|---|---|
| `syncSoundCloud` | Every 60 minutes | Fetches SoundCloud RSS |
| `syncYouTube` | Every 60 minutes | Fetches YouTube channel videos |

Both functions upsert (not overwrite) — existing docs are merged, preserving `playCount` and any manually added fields.
