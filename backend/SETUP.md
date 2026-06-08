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

## 7. Set admin custom claims (for write access)

Firestore rules restrict writes to users with `admin: true` custom claim.
Set this from a trusted server environment or via the Firebase Admin SDK:

```typescript
import { getAuth } from 'firebase-admin/auth';

// Set admin claim for a user by UID
await getAuth().setCustomUserClaims('USER_UID_HERE', { admin: true });
```

Or use the Firebase CLI extension / Admin SDK script once you have a service account.

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

---

## Scheduled function schedule

| Function | Schedule | Notes |
|---|---|---|
| `syncSoundCloud` | Every 60 minutes | Fetches SoundCloud RSS |
| `syncYouTube` | Every 60 minutes | Fetches YouTube channel videos |

Both functions upsert (not overwrite) — existing docs are merged, preserving `playCount` and any manually added fields.
