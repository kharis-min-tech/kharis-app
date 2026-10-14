# Mobile integration guide

This guide is for developers working on the Flutter app in `app/`. It explains how the app's data layer connects to the backend:

- which repository and provider reads which endpoint or collection
- the timeouts, retries and fallbacks each one uses
- caching
- differences between web and mobile builds
- environment configuration
- how to add an endpoint
- how to test

Related documents:

- [`API.md`](API.md): request and response shapes, Firestore rules and push notifications.
- [`openapi.yaml`](openapi.yaml): machine-readable description of the HTTP endpoints.

In prose a church location is called a **Branch**. Code and data keep their historical names: the `branch` field, `CampusVenue`, `campus_config.dart`, and so on.

Most providers live in `app/lib/shared/providers/sermon_provider.dart`. Other provider files are named in the table.

## 1. Repository map

| Area | Repository (file) | Provider | Remote source | Fallbacks, in order |
|---|---|---|---|---|
| Sermon library | `R2MessagesRepository` (`features/messages/data/r2_messages_repository.dart`) | `sermonRepositoryProvider` | R2 `messages.json` plus page 1 of the sermon API, merged ([API.md 3.4](API.md#34-how-the-app-merges-r2-with-the-api)) | 1. paged sermon API<br>2. Hive archive<br>3. empty library marked offline, with Retry |
| Sermon API paging and search | `KharisApiSermonRepository` (`kharis_api_sermon_repository.dart`) | used by the R2 repository | `ApiConfig.sermonApiBase` + `sermons/` ([API.md 2](API.md#2-public-sermon-api-yetanothersermonhost)) | none (the library notifier retries) |
| Hand-added sermons, pinned featured | `FirestoreSermonRepository` (`firestore_sermon_repository.dart`, read-only) | `firestoreSermonRepositoryProvider`, `cmsSermonsProvider`, `pinnedFeaturedProvider` | Firestore `sermons` | none |
| Featured mode | `CurationRepository` (`curation_repository.dart`) | `curationRepositoryProvider`, `featuredModeProvider` | `config/featured.mode` | `auto` when the doc is missing or on error |
| Videos | `VideoRepository` (`video_repository.dart`) | `videoRepositoryProvider`, `videosProvider` | YouTube Data API `playlistItems` + `videos` ([API.md 4](API.md#4-youtube-data-api)) | 1. channel Atom feed<br>2. embedded `kharisVideos` (`kharis_content.dart`) |
| Live banner | `LiveRepository` (`features/home/data/live_repository.dart`) | `liveRepositoryProvider`, `liveStatusProvider` | Content Studio `app_config` row `key = liveStream`: `{url, title, enabled \| is_live}` (network only, never cached) | not live |
| Branches | `BranchRepository` (`features/onboarding/data/branch_repository.dart`) | `branchRepositoryProvider`, `branchesProvider` (`admin_provider.dart`); `weeklyServicesProvider` (`campus_config_provider.dart`) | Content Studio `branches` (`is_active`), `services` (`is_active`) and `venues`, joined by `branch_id`; `Branch.id` is the slug, ordered main group then KP2, each by `sort_order` | last good response saved in Hive (`ContentApi`); error when nothing is saved |
| Giving and Home layout | none (`campus_config_provider.dart`) | `effectiveGivingProvider`, `effectiveHomeLayoutProvider` | Branch `giving_link` | `kBuiltInGiving` (kharis.org/giving); Home always uses `HomeLayout.fallback` |
| Announcements | `NewsRepository` (`features/home/data/news_repository.dart`) | `newsRepositoryProvider`, `newsProvider` | Content Studio `news`, mapped defensively, filtered on the device to published, unexpired and the member's Branch | last good response saved in Hive; empty list when the table is empty |
| Events | `EventRepository` (`features/calendar/data/event_repository.dart`) | `eventRepositoryProvider`, `upcomingEventsProvider`, `pastEventsProvider` | Content Studio `events`. `branch_name` null means every Branch. `recurrence = weekly` expands into one event per `recurrence_days` date (0 = Sunday) until `recurrence_until`, at most 8 weeks ahead; occurrence ids are `<id>~<yyyymmdd>` | last good response saved in Hive |
| RSVPs | `RsvpRepository` (`rsvp_repository.dart`) | `rsvpRepositoryProvider` | Firestore `rsvps/{uid}_{eventId}` | none |
| Daily reading | `DailyContentRepository` (`features/home/data/daily_content_repository.dart`) | `dailyContentRepositoryProvider` | `GET getDailyReading` | 1. `dailyContent/{date}`<br>2. `readingPlans` resolved on the device (same rules as the server)<br>3. built-in Psalm 23 |
| Reading plans | `ReadingPlanRepository` (`reading_plan_repository.dart`) | `readingPlanRepositoryProvider` (`reading_plan_provider.dart`) | Firestore `readingPlans` | none |
| Bible text | `BibleRepository` (`features/home/data/bible_repository.dart`) | `bibleRepositoryProvider` | YouVersion `https://api.youversion.com/v1` (`/bibles`, `/bibles/{id}/passages/{usfm}`), header `x-yvp-app-key` | in-memory cache only |
| Notifications (push) | `NotificationService` (`core/services/notification_service.dart`) | `notificationServiceProvider`, `notificationInitProvider`, `notificationTopicSyncProvider` (`shared/providers/notification_provider.dart`) | FCM topics ([API.md 7.1](API.md#71-fcm-topics)). Writes `users/{uid}.fcmToken`. A tap routes by `data.type` (`notificationTargetFor`). | none |
| Auth and profile | `FirebaseAuthRepository` (`features/onboarding/data/firebase_auth_repository.dart`) | `firebaseAuthRepositoryProvider`, `authRepositoryProvider` (`auth_provider.dart`) | Firebase Auth (email or anonymous) and `users/{uid}` | none |
| Account deletion | `AccountDeletionService`, `AccountDataRepository`, `LocalAccountData` (`features/settings/data/account_deletion.dart`); UI in `features/settings/presentation/widgets/delete_account_flow.dart` | `accountDeletionServiceProvider`, `accountDataRepositoryProvider`, `localAccountDataProvider` | Password re-auth, then batched deletes of `users/{uid}/notes`, `users/{uid}/playlists`, `rsvps` (`userId == uid`) and `users/{uid}`, then `currentUser.delete()`. `requires-recent-login` prompts for the password and retries. See [API.md 6.8](API.md#68-users). | none; errors are shown and nothing local is cleared until the account is gone |
| Onboarding state | `OnboardingRepository` | `onboardingRepositoryProvider` | SharedPreferences only | none |
| Notes | `NoteRepository` + `LocalNoteStore` (`features/notes/data/note_repository.dart`) | `notesRepositoryProvider`, `localNoteStoreProvider` (`notes_provider.dart`) | `users/{uid}/notes` | Hive `notes` box; local notes are uploaded on sign-in |
| Playlists and Favorites | `PlaylistRepository` (`features/playlists/data/playlist_repository.dart`) | `playlistRepositoryProvider` | `users/{uid}/playlists`; Favorites is the doc `liked` | Firestore offline write queue |
| Feedback | `AppFeedbackRepository` (`features/feedback/data/app_feedback_repository.dart`) | `appFeedbackRepositoryProvider` | `app_feedback` | after a 6 s acknowledgement timeout, the write is treated as sent |
| Connect forms | `ConnectRepository` (`features/connect/data/connect_repository.dart`) | `connectRepositoryProvider` | `visitors`, `testimonies` | none; errors are thrown |
| Audio | `AudioPlayerService` (`features/player/data/audio_player_service.dart`) | `audioPlayerServiceProvider` | sermon `audioUrl`, which 302-redirects to signed R2 | manual retry only |

Content (branches, services, venues, events, announcements, featured videos, live) is managed in the Kharis Content Studio (https://kharis-content.itadmin-a94.workers.dev, Supabase). The app has no Studio of its own and no admin roles. The Notifications screen lists upcoming events and live announcements (`campusUpcomingEventsProvider`, `campusNewsProvider`); pushes composed in a Studio are not available until the Content Studio supports them, so only the automatic pushes ([API.md 7](API.md#7-push-notifications)) arrive.

## 2. Timeouts, retries and offline behaviour

| Client | Connect | Receive | Retry |
|---|---|---|---|
| Content Studio reads (`ContentApi`: branches, services, venues, events, news, app_config) | 10 s | 20 s | None. A failed call serves the last good response saved in Hive (live status excepted). |
| `DailyContentRepository` (`getDailyReading`) | 12 s | 15 s | None. A failed call goes to the Firestore fallback. |
| `KharisApiSermonRepository` | 15 s | 20 s | Handled by the library notifier (below). |
| `R2MessagesRepository` mirror | 10 s | 20 s per request | None. An overall `mirrorDeadline` of **25 s** applies, after which page 1 falls back to the sermon API. |
| `BibleRepository` | Dio default | Dio default | One retry after 800 ms, only for connection errors (no response). |
| `VideoRepository` (feed fetch) | Dio default | Dio default | None. Falls back to the Atom feed, then the embedded list. |
| Audio (`just_audio`) | n/a | load timeout 25 s | Manual `retry()` from the UI |

How the sermon library loads (`SermonLibraryNotifier`, `sermon_provider.dart`):

- The library is walked page by page. A failed page is retried with `defaultArchiveBackoff`: 2, 4, 8 … seconds, capped at 60 s, for at most 5 attempts.
- The fully walked archive is stored in Hive with its `fetchedAt` time. It is considered fresh for 24 hours (`maxAge`). After that it is re-walked at launch or on pull-to-refresh, while the cached copy stays on screen.
- With no network and no cache, the bundled archive is shown.

Firestore streams use the SDK's default persistence. The app sets no custom `Settings`.

## 3. Caching

**Hive** (`core/services/cache_service.dart`, boxes opened at startup):

- `sermons`
  - Key `sermon_archive_v2` holds `{v: 2, fetchedAt, sermons[]}`. It is encoded and decoded on a background isolate with `compute`.
  - The legacy key `sermons_list` is deleted on write.
- `preferences`
  - `recently_played` (max 20)
  - `recent_sermon_snapshots` (max 30)
  - `playback_speed`, `last_sort`, `last_category`
- `playback_positions`, keyed by `yt_<videoId>` and by the raw sermon id
- `notes`, offline note drafts
- `events`, opened but unused

**Images**:

- `cached_network_image` with the default cache manager.
- `shared/widgets/artwork_image.dart` sets `memCacheWidth` clamped to 64–1080.
- Sermon thumbnails are requested at `?width=512` (`biggerSermonImage`).

**HTTP caching**: the server sets `Cache-Control` per endpoint (see [API.md](API.md)). The app adds no HTTP cache layer. The mobile Dio client ignores `Cache-Control`; browsers honour it.

**SharedPreferences**: onboarding state (`onboarding_*`) and review-prompt counters (`review_*`). Deleting an account clears the `notes` box and the `onboarding_*` keys, so the app restarts at Welcome.

## 4. Web vs mobile

| Concern | Mobile (iOS/Android) | Web |
|---|---|---|
| Sermon API | Direct to `yetanothersermon.host`, sending `User-Agent: kBrowserUserAgent` | Through `sermonApiProxy`. Browsers cannot set a User-Agent, and the upstream has no CORS. As of 2026-10-05 the proxy is not deployed, so web shows the bundled archive. |
| R2 `messages.json` / transcripts | Used | Blocked: the bucket sends no CORS headers. Page 1 falls back to the API, so web has **no transcripts** until the bucket CORS fix in [API.md 8](API.md#8-ops-r2-bucket-cors) is applied. |
| YouTube Atom feed fallback | Dio | Browser `fetch` (`feed_fetch_web.dart`), which usually fails CORS. The embedded list is shown instead. |
| Cloud Functions reads | Direct | Direct (`cors: true`) |
| Audio | `just_audio` with the browser UA, following the 302 | Browser audio element; the 302 to signed R2 is followed natively |
| Store review | `in_app_review` | Unavailable |
| `app_feedback.platform` | `defaultTargetPlatform.name` | `web` |

The web builds are hosted at:

- `https://kharis-app-47c49.web.app` (`app/firebase.json`)

## 5. Environment configuration

Build-time secrets come from `app/env.json`, passed with `--dart-define-from-file=env.json`. The file is gitignored; `app/env.example.json` documents the keys.

| Key | Read by | Effect when empty |
|---|---|---|
| `YOUVERSION_API_KEY` | `BibleRepository` (`String.fromEnvironment`) | Bible text throws a `StateError` and the reader shows its error state |
| `YOUTUBE_API_KEY` | `VideoRepository` | The Data API is skipped and the Atom feed or embedded videos are used |

Every build and run script passes the file:

- `scripts/build-web.sh`, `build-android.sh`, `build-ios.sh`, `deploy-testflight.sh`, `deploy-ministries.sh`, and the `run_e2e.sh` journey runner
- CI restores it from the `ENV_JSON` secret
- local development: `flutter run --dart-define-from-file=env.json`

Other configuration is in code:

- `ApiConfig` (`core/constants/api_config.dart`): the Firebase project `kharis-app-47c49`, the region, endpoint URLs and the sermon API base. At startup, `warnIfProjectSplit()` logs a banner if `firebase_options.dart` points at a different project.
- `http_constants.dart`: `kBrowserUserAgent`, `kR2BucketBaseUrl`, `kR2MessagesUrl`. To move the bucket, change only `kR2BucketBaseUrl`.

The Cloud Functions YouTube key is a Functions parameter (`YOUTUBE_API_KEY`, `defineString`) set at deploy time, not in `env.json`.

## 6. Adding a new endpoint

The existing read endpoints all follow the same pattern. Copy it:

1. **Backend.** Add an `onRequest` handler in `backend/functions/src`, and export it from `index.ts`.
   - Use `{ memory: '256MiB', timeoutSeconds: 30, cors: true }`.
   - Return `405` for non-GET requests.
   - Set `Cache-Control: public, max-age=300` when the data can be shared.
   - Return `{ <items>: [...], count }` with ISO timestamps.
   - Keep the selection logic in a pure module, as `announcements.ts` and `events-api.ts` do, so it can be unit-tested in `backend/functions/test`.
2. **Endpoint constant.** Add `static const String getX = '$_base/getX';` to `ApiConfig`. Do not hard-code hosts in repositories.
3. **Repository** in `app/lib/features/<area>/data/`:
   - Accept an optional `Dio` and `FirebaseFirestore` in the constructor.
   - Default to `Dio(BaseOptions(connectTimeout: 12 s, receiveTimeout: 15 s))`.
   - Call the API first. On any error, return `null` or fall through to the Firestore query that produces the same list with the same rules, then to a built-in default.
   - Run heavy mapping through `compute` when the payload is large.
4. **Provider.** Add it in `app/lib/shared/providers/` next to the related providers. Gate Firestore-backed providers on `kUseFirebase`.
5. **Rules.** If the Firestore fallback reads a new collection, add the collection to `backend/firestore.rules` and a case to `backend/functions/test/rules/firestore-rules.test.ts`.
6. **Docs.** Add the endpoint to [API.md](API.md) and [openapi.yaml](openapi.yaml), then run `npx -y @redocly/cli lint docs/openapi.yaml --skip-rule no-path-trailing-slash`. The sermon API paths really do end in `/`, so that rule is skipped.

## 7. Testing

**Unit and widget tests** (`app/test`, run with `flutter test <file>`):

- **HTTP**: inject a `Dio` whose `httpClientAdapter` is a stub. Examples:
  - `_StubAdapter` and `_OfflineAdapter` in `announcements_home_pipeline_test.dart`
  - `_FixtureAdapter` and `_RoutingAdapter` (multi-page `next` walks) in `kharis_api_repository_test.dart`
  - `_ScriptedAdapter` (retry) in `bible_repository_retry_test.dart`
  - `_ArchiveAdapter` in `sermon_archive_hydration_test.dart`
- **R2 merge and deadlines**: `r2_messages_repository_test.dart` uses a `_FakeApi extends KharisApiSermonRepository` and a short `mirrorDeadline` (50 ms) to cover the fallback to the sermon API.
- **Firestore**: `fake_cloud_firestore` (`FakeFirebaseFirestore`), injected through repository constructors or `firestoreProvider`. Examples: `content_repositories_test.dart`, `event_tombstone_test.dart`.
- **Shared fakes** in `test/support/`:
  - `FakeAudioPlayerService`
  - `FakeCacheService`
  - `FakeJustAudioPlatform`
  - `FakePagedSermonRepository`
- **Paging**: `_FakePagedRepo` in `sermon_library_pagination_test.dart`.

Backend:

- Functions unit tests are in `backend/functions/test`.
- Firestore rules tests are in `backend/functions/test/rules/firestore-rules.test.ts`, run with `npm run test:rules`.

**On-device journeys** (`app/integration_test/e2e_test.dart`) run the real app on a simulator or emulator against the live backends. Run them from `app/`:

```sh
scripts/run_e2e.sh ios                      # every journey
scripts/run_e2e.sh android events player    # only these journeys
```

- Journeys: `onboarding`, `branch_switch`, `events`, `messages`, `player`, `playlists`, `bible`, `giving`, `forms`, `deep_links`, `display`, `account`, `more_menu`, `notifications`. Each is its own `testWidgets` in `integration_test/journeys/`, launches the app in a fresh `ProviderContainer` after clearing SharedPreferences and playback history, and never depends on another journey. A failing journey does not stop the rest.
- Expectations come from the live sources at run time (`integration_test/support/live_data.dart`): Content Studio rows over Supabase REST, the sermon API count, the R2 catalogue (transcripts) and YouVersion (books, versions). When live data is empty the journey checks the empty state and logs a `DATA:` note. Nothing is pinned to a branch: random choices (branch, book, message, version) are seeded by the date and logged, so a day's runs repeat and the next day's differ. Override with `E2E_SEED=YYYYMMDD`.
- Platform hand-offs are answered in Dart (`integration_test/support/channels.dart`): url_launcher (the journeys assert the URL and external mode), the OS share sheet (a headless iOS simulator cannot dismiss it) and add_2_calendar (nothing is added). Firebase Messaging calls pass through and are recorded.
- Writes stay on the test's own anonymous account and are undone in the same journey (an RSVP, a playlist, a like, a note). The forms journey posts to a stubbed Dio adapter, never to the Studio. The account journey uses a fake signed-in member and a recording deletion service: no real account is deleted.
- The script boots the device if needed (iOS `F7F25682-…` or `E2E_DEVICE`; Android: the running emulator, else AVD `E2E_AVD`, default `Pixel_10_Pro_XL`), does a fresh install, pre-grants notification permission, and runs `flutter test integration_test/e2e_test.dart --dart-define-from-file=env.json`.
- Output in `/tmp/kharis-e2e-<platform>/`: one folder of screenshots per journey (`KSHOT:<journey>/<name>`), `run.log`, `findings.txt` (`KCHECK:FAIL` and `KNOTE` lines) and `summary.txt`, the table of journey, `PASS`/`FAIL`/`SKIP (reason)` and duration. The script exits non-zero on any `FAIL`.
- Every `FlutterError` during a journey (a `RenderFlex` overflow included) fails that journey. When the error is a framework invariant (duplicate `GlobalKey`, build-scope or layout assertions), the process's widget tree is no longer usable: the journeys after it report `DEFER` and the script reruns them in a fresh `flutter test` process (listed in `reruns.txt`).

**Manual checks against production** (read-only):

```sh
curl -s 'https://us-central1-kharis-app-47c49.cloudfunctions.net/getEvents?when=past&limit=1'
curl -sI -H 'Origin: https://kharis-app-47c49.web.app' \
  https://pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev/messages.json
```
