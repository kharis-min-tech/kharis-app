# Kharis Church — Build & Release Guide

Everything needed to go from code to App Store and Play Store.

---

## Prerequisites

Before starting, confirm you have:

| Tool | Version | Notes |
|---|---|---|
| macOS | 13+ | Required for iOS builds |
| Xcode | 15+ | Install from the Mac App Store |
| Flutter | 3.44+ | `flutter --version` to check |
| Dart SDK | 3.12.1+ | Bundled with Flutter 3.44+; `pubspec.yaml` pins `^3.12.1`. If `flutter run` spews thousands of URI/resolution errors, your Flutter is too old — run `flutter upgrade` |
| Android Studio / SDK | Latest | Or just Android command-line tools |
| Java | 17 | `java -version`; use Temurin if unsure |
| Node.js | 18+ | For Firebase CLI and backend functions |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| Apple Developer account | — | $99/yr at developer.apple.com |
| Google Play Console account | — | $25 one-time at play.google.com/console |

Verify Flutter is set up correctly:

```bash
flutter doctor -v
```

All items should be green before proceeding. Fix any ✗ entries — missing Android licenses and Xcode command-line tools are the most common blockers.

---

## Step 1: Firebase Setup

### 1.1 Create the project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `kharis-church`
3. Disable Google Analytics if not needed → **Create project**

### 1.2 Enable required services

In the Firebase Console for the project:

**Firestore Database**
- Build → Firestore Database → **Create database**
- Choose **Production mode** (rules are deployed via CLI)
- Region: `europe-west2` (London) — closest to most UK users

**Authentication**
- Build → Authentication → **Get started**
- Enable **Email/Password**

**Cloud Messaging**
- Build → Cloud Messaging is enabled by default once you add the apps below

**Cloud Functions**
- Build → Functions → **Get started**
- The project must be on the **Blaze (pay-as-you-go)** plan — free tier does not support outbound network calls in functions

### 1.3 Configure Firebase with FlutterFire CLI

The FlutterFire CLI automatically registers your app with Firebase and generates the configuration file. This is cleaner than manually downloading JSON/plist files.

**Install the CLI (one-time):**

```bash
dart pub global activate flutterfire_cli
```

**Run configure:**

```bash
cd app
flutterfire configure --project=kharis-church
```

The CLI will:
1. Prompt you to select platforms (Android, iOS, Web, macOS)
2. Register apps in Firebase Console automatically
3. Generate `lib/firebase_options.dart` with all platform configs
4. Download `google-services.json` and `GoogleService-Info.plist` to the correct locations

> **Package name:** When prompted, use `org.kharis.app` for both Android and iOS. The CLI will update `build.gradle.kts` and Xcode project if needed.

### 1.4 Enable Firebase in the Flutter app

Open `app/lib/core/services/firebase_service.dart` and change:

```dart
const bool kUseFirebase = false;
```

to:

```dart
const bool kUseFirebase = true;
```

This single flag controls whether the app hits real Firebase or mock data.

### 1.5 Verify configuration

```bash
# Check that firebase_options.dart was generated
cat app/lib/firebase_options.dart | head -20

# Should show your actual project ID, not "PLACEHOLDER"
```

---

## Step 2: Backend Deploy

### 2.1 Link the CLI to the project

```bash
cd backend
firebase login
firebase use --add
# Select the kharis-church project and alias it "default"
```

### 2.2 Set the YouTube API key

Get a YouTube Data API v3 key from [console.cloud.google.com](https://console.cloud.google.com) → APIs & Services → Credentials.

For production (recommended — uses Firebase Secrets, not env files):

```bash
firebase functions:secrets:set YOUTUBE_API_KEY
# Enter the key when prompted
```

For local development only:

```bash
echo "YOUTUBE_API_KEY=YOUR_KEY_HERE" > backend/functions/.env
```

### 2.3 Install and build functions

```bash
cd backend/functions
npm install
npm run build
```

### 2.4 Deploy

```bash
cd backend
firebase deploy --only functions,firestore
```

Deploy subsets when needed:

```bash
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### 2.5 Verify SoundCloud sync

After deploy, the `syncSoundCloud` function runs on a 60-minute schedule. To verify manually:

1. Firebase Console → Functions → `syncSoundCloud` → **Run now** (or wait one hour)
2. Check Firestore → `sermons` collection — new documents should appear with `source: "soundcloud"`

---

## Step 3: Admin Panel

### 3.1 Configure Firebase

Open `admin/index.html` and find the Firebase config block near the top. Replace the placeholder values with your actual project config from Firebase Console → Project Settings → Your apps → Web app:

```javascript
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "kharis-church.firebaseapp.com",
  projectId: "kharis-church",
  storageBucket: "kharis-church.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID"
};
```

### 3.2 Run locally or deploy

**Local (Docker):**

```bash
cd admin
docker compose up --build
# Admin panel at http://localhost:8080
```

**Firebase Hosting (optional):**

```bash
firebase deploy --only hosting
```

### 3.3 Create the first admin user

1. Firebase Console → Authentication → **Add user**
2. Enter the admin email and password
3. Copy the UID

### 3.4 Set the admin custom claim

The Firestore rules require `admin: true` on the user's token for write access. Set this from the Firebase Console using the Admin SDK script, or run it locally with a service account:

```typescript
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

initializeApp({ credential: cert('./serviceAccountKey.json') });

// Replace with the UID from step 3.3
await getAuth().setCustomUserClaims('USER_UID_HERE', { admin: true });
```

After setting the claim, the user must sign out and back in for the token to refresh.

---

## Step 4: Android Build

### 4.1 Confirm the package name

The `applicationId` in `app/android/app/build.gradle.kts` is currently:

```
org.kharis.kharis_app
```

The Play Console registration and Firebase Android app must use the exact same value. If you want `org.kharis.app`, update `build.gradle.kts` before creating the keystore — changing the package name after publishing is not possible.

### 4.2 Generate the release keystore

Run the keystore generator script once. **Do this exactly once — the keystore is permanent. If lost, you cannot publish updates to the Play Store.**

```bash
cd app
chmod +x scripts/generate-keystore.sh
./scripts/generate-keystore.sh
```

The script will:
- Create `android/keystore/kharis-release.jks` (alias: `kharis-release`)
- Write `android/key.properties` with your passwords
- Add both to `.gitignore` automatically

> **Critical:** Back up `android/keystore/kharis-release.jks` and both passwords to a secure location (1Password, Bitwarden, etc.) immediately. This file is not committed to git.

### 4.3 Wire signing into the build

The default `build.gradle.kts` signs release builds with the debug key. Replace the `buildTypes` block in `app/android/app/build.gradle.kts`:

```kotlin
android {
    // ... existing config above ...

    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            val keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                props.load(keyPropsFile.inputStream())
            }
            storeFile = file(props["storeFile"] as String)
            storePassword = props["storePassword"] as String
            keyAlias = props["keyAlias"] as String
            keyPassword = props["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
        }
    }
}
```

`key.properties` is at `android/key.properties` (one level up from `android/app/`), which is the path written by the keystore script.

### 4.4 Build the App Bundle

```bash
cd app
flutter pub get
flutter build appbundle --release
```

Output: `app/build/app/outputs/bundle/release/app-release.aab`

To include a specific version:

```bash
flutter build appbundle --release --build-name=2.0.0 --build-number=1
```

### 4.5 Upload to Play Console

1. Go to [play.google.com/console](https://play.google.com/console)
2. Create the app if this is the first upload: **Create app** → name `Kharis Church`, default language English (UK), app type Application, free
3. Production → Releases → **Create new release**
4. Upload `app-release.aab`
5. Fill in release notes (copy from `APP-STORE-LISTING.md` → What's New)
6. **Save** → **Review release** → **Start rollout to production**

For first-time internal testing before production, use **Internal testing** track instead.

---

## Step 5: iOS Build

### 5.1 Apple Developer account setup

Before building, in [developer.apple.com](https://developer.apple.com):

1. **Register the App ID:** Certificates, Identifiers & Profiles → Identifiers → **+** → App IDs → `org.kharis.app`
   - Enable: Push Notifications (required for Firebase Messaging)
2. **Create a Distribution Certificate:** Certificates → **+** → Apple Distribution → follow the CSR steps
3. **Create an App Store Provisioning Profile:** Profiles → **+** → App Store → select `org.kharis.app` → select the distribution certificate → name it `Kharis App Store`

Install the certificate and provisioning profile on the build machine by double-clicking each downloaded file.

### 5.2 Set the Team ID and provisioning profile

Open `app/ios/exportOptions.plist` and replace the placeholders:

```xml
<key>teamID</key>
<string>YOUR_10_CHAR_TEAM_ID</string>   <!-- from developer.apple.com → Membership -->

<key>provisioningProfiles</key>
<dict>
    <key>org.kharis.app</key>
    <string>Kharis App Store</string>   <!-- exact name of the profile created above -->
</dict>
```

The Team ID is a 10-character alphanumeric string visible in developer.apple.com → Account → Membership.

### 5.3 Configure Xcode (first time only)

```bash
open app/ios/Runner.xcworkspace
```

In Xcode:
1. Select the **Runner** target → **Signing & Capabilities**
2. Set **Team** to your Apple Developer team
3. Confirm **Bundle Identifier** is `org.kharis.app`
4. Under **Release** build configuration, set signing to **Manual** and select the `Kharis App Store` provisioning profile

Or use the bundle ID script if starting fresh:

```bash
cd app
chmod +x scripts/set-bundle-id.sh
./scripts/set-bundle-id.sh org.kharis.app "Kharis Church"
```

### 5.4 Build the IPA

```bash
cd app
flutter pub get
chmod +x scripts/build-ios.sh
./scripts/build-ios.sh
```

This runs `flutter build ipa --release --export-options-plist=ios/exportOptions.plist`.

Output: `app/build/ios/ipa/kharis_app.ipa` (path may vary — the script prints the exact path)

To build manually without the script:

```bash
flutter build ipa --release --export-options-plist=ios/exportOptions.plist
```

### 5.5 Create the app in App Store Connect

Before uploading for the first time:

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → **+** → New App
2. Platform: iOS
3. Name: `Kharis Church`
4. Primary language: English (UK)
5. Bundle ID: `org.kharis.app` (select from list — it appears once you registered the App ID)
6. SKU: `kharis-church-ios` (internal, not user-facing)

### 5.6 Upload to App Store Connect

**Option A — Xcode Organizer (recommended for first upload):**

```bash
open app/ios/Runner.xcworkspace
# Window → Organizer → Archives → select the build → Distribute App → App Store Connect
```

**Option B — xcrun altool (command line):**

Requires an app-specific password from [appleid.apple.com](https://appleid.apple.com) → App-Specific Passwords.

```bash
xcrun altool --upload-app \
  --type ios \
  --file "path/to/kharis_app.ipa" \
  --username "YOUR_APPLE_ID_EMAIL" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

**Option C — App Store Connect API key (for CI):**

1. App Store Connect → Users and Access → **Integrations** → App Store Connect API → **Generate API Key**
2. Download the `.p8` file
3. Note the Key ID and Issuer ID

```bash
xcrun altool --upload-app \
  --type ios \
  --file "path/to/kharis_app.ipa" \
  --apiKey "YOUR_KEY_ID" \
  --apiIssuer "YOUR_ISSUER_ID"
```

---

## Step 6: TestFlight and Internal Testing

### 6.1 Internal testing (immediate, no review)

1. App Store Connect → your app → **TestFlight**
2. The build uploaded in Step 5.6 appears under **iOS Builds** once processing completes (5–30 minutes)
3. Click the build → **Enable** under Internal Testing
4. Add internal testers: TestFlight → **Internal Testing** → **+** to add App Store Connect users (up to 100)
5. Testers install TestFlight from the App Store and accept the email invitation

### 6.2 External testing (requires brief review, up to 10,000 testers)

1. TestFlight → **External Groups** → **+** → create a group
2. Add builds to the group
3. Submit for **Beta App Review** — usually approved within 24 hours
4. Share the public link or add testers by email

### 6.3 Test checklist on real devices

Before submitting to the App Store, verify on physical hardware:

- [ ] App launches and splash screen shows correctly
- [ ] Branch selection screen appears on first launch
- [ ] Home screen loads sermons from Firestore (requires `kUseFirebase = true` and real config files)
- [ ] Audio player plays a sermon in background (lock the phone, confirm audio continues)
- [ ] Daily prayer card loads
- [ ] Events tab shows upcoming events
- [ ] Give button opens the giving page
- [ ] Push notifications arrive (send a test from Firebase Console → Cloud Messaging)
- [ ] App works on both small (iPhone SE) and large (iPhone Pro Max) screens

---

## Step 7: Store Submission

### 7.1 Prepare screenshots

Required dimensions — all screenshots must match exactly:

**iOS (App Store Connect):**
- 6.9-inch: 1320 × 2868 px (iPhone 16 Pro Max)
- 6.5-inch: 1284 × 2778 px (iPhone 14 Plus / 15 Plus)

**Android (Play Console):**
- Phone: 1080 × 1920 px minimum, 9:16 ratio

Required screenshots per `APP-STORE-LISTING.md`:

| # | File | Caption |
|---|---|---|
| 1 | screenshot-01-home.png | "Everything in one place" |
| 2 | screenshot-02-sermons.png | "Every sermon, on demand" |
| 3 | screenshot-03-player.png | "Listen anywhere, even offline" |
| 4 | screenshot-04-prayer.png | "Start your day grounded" |
| 5 | screenshot-05-events.png | "Never miss what is happening" |
| 6 | screenshot-06-branch-giving.png | "Built for your branch" |

Also required for Play Store: feature graphic at 1024 × 500 px (`feature-graphic.png`). See `APP-STORE-LISTING.md` for the exact design spec (dark background, white dove logo, purple glow).

### 7.2 iOS — App Store Connect submission

In App Store Connect → your app → **1.0 Prepare for Submission** (or create a new version):

**App Information:**
- Name: `Kharis Church`
- Subtitle: `Sermons, Prayer & Community`
- Primary Category: Lifestyle
- Secondary Category: Music
- Content Rating: 4+

**Version Information:**
- Description: copy from `APP-STORE-LISTING.md` → App Store → Description
- Keywords: `church,sermons,prayer,bible,giving,worship,christian,audio,kharis,pastor,devotional`
- What's New: copy from `APP-STORE-LISTING.md` → What's New — v2.0
- Support URL: `https://kharis.org`
- Privacy Policy URL: `https://kharis.org/privacy-policy`

**Build:** select the TestFlight build you validated

**App Review Information:**
- Sign-in required: No (the app works without an account)
- Notes for reviewer: "Sermons and daily prayer are accessible without sign-in. Branch selection appears on first launch."

Click **Add for Review** → **Submit to App Review**.

Review time is typically 24–48 hours. You will receive an email when approved or if action is needed.

### 7.3 Android — Play Console submission

In Play Console → your app:

**Store listing:**
- App name: `Kharis Church`
- Short description: copy from `APP-STORE-LISTING.md` → Play Store → Short Description
- Full description: copy from `APP-STORE-LISTING.md` → Play Store → Full Description
- App icon: 512 × 512 px PNG (no transparency)
- Feature graphic: 1024 × 500 px PNG
- Screenshots: upload the 6 screenshots above

**App content:**
- Content rating: complete the questionnaire → Everyone
- Target audience: 18+
- Data safety: complete the form (the app collects Firebase Analytics and optionally user accounts)

**Production release:**
- Production → Releases → select the `.aab` uploaded in Step 4.5
- Roll out to 100% (or staged rollout starting at 10% if preferred)

Play Store review takes 1–3 days for new apps, typically hours for updates.

---

## Step 8: CI/CD (GitHub Actions)

Four workflow files are in `.github/workflows/`. They run on `workflow_dispatch` (manual trigger from the GitHub Actions tab).

### Required GitHub secrets

Set these in the repo: Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | `base64 -i android/keystore/kharis-release.jks` output |
| `KEY_PROPERTIES` | contents of `android/key.properties` |
| `FIREBASE_TOKEN` | output of `firebase login:ci` |

To encode the keystore:

```bash
base64 -i app/android/keystore/kharis-release.jks | pbcopy
# Paste into the KEYSTORE_BASE64 secret
```

### Workflows

| Workflow | File | Trigger | Output |
|---|---|---|---|
| CI | `ci.yml` | Push / PR | Runs `flutter analyze` + `flutter test` |
| Android build | `build-android.yml` | Manual | `android-release-aab` artifact |
| iOS build | `build-ios.yml` | Manual (macOS runner) | `ios-release-ipa` artifact |
| Backend deploy | `deploy-backend.yml` | Manual | Deploys functions + Firestore rules |

> Note: The iOS CI workflow builds without code signing (`--no-codesign`). Final IPA signing for App Store upload is done locally via `scripts/build-ios.sh` until App Store Connect API key signing is configured.

---

## Troubleshooting

### Firebase

**`kUseFirebase = true` but app crashes on launch**
- Confirm both `google-services.json` and `GoogleService-Info.plist` are in the correct directories and committed (or present locally)
- Run `flutter clean && flutter pub get` then rebuild
- Check that the bundle ID / package name in the config files matches the app

**Functions deploy fails with billing error**
- The project must be on the Blaze plan. Upgrade in Firebase Console → Project Settings → Usage and billing

**Admin custom claim not taking effect**
- The user must sign out and sign back in after the claim is set — Firebase ID tokens are cached for 1 hour

---

### Android

**`flutter build appbundle` fails — signing error**
- Confirm `android/key.properties` exists and paths are correct
- The `storeFile` path in `key.properties` is relative to the `android/app/` directory (e.g. `../keystore/kharis-release.jks`)
- Confirm `key.properties` is being loaded in `build.gradle.kts`

**`keytool: command not found`**
- Ensure Java 17 is installed and `JAVA_HOME` is set: `export JAVA_HOME=$(/usr/libexec/java_home -v 17)`

**Play Console rejects the AAB — "You uploaded an APK or Android App Bundle that was signed in debug mode"**
- The `buildTypes.release.signingConfig` is still pointing to `debug`. Double-check the `build.gradle.kts` changes in Step 4.3

**`minSdk` errors**
- `flutter.minSdkVersion` resolves to 21. If a plugin requires higher, set `minSdk = 23` (or required value) explicitly in `defaultConfig`

---

### iOS

**`flutter build ipa` fails — no signing certificate**
- The Apple Distribution certificate must be installed on the build machine
- Run `security find-identity -v -p codesigning` to list installed certificates

**`exportOptions.plist` error: provisioning profile not found**
- The name in `exportOptions.plist → provisioningProfiles → org.kharis.app` must exactly match the profile name in Xcode's Signing & Capabilities and in your local keychain
- Download and re-install the provisioning profile from developer.apple.com

**`This app's Info.plist file does not have a NSMicrophoneUsageDescription`**
- If a plugin requires it, add to `ios/Runner/Info.plist`:
  ```xml
  <key>NSMicrophoneUsageDescription</key>
  <string>Required for audio features</string>
  ```

**Xcode: "No account for team"**
- Sign in to Xcode with your Apple ID: Xcode → Settings → Accounts → **+**

**App uploaded to TestFlight but not visible**
- Processing takes up to 30 minutes. Check the build status in App Store Connect → TestFlight — it will show "Processing" then "Ready to Submit"
- If it shows "Missing Compliance" — answer the export compliance question (the app uses standard HTTPS encryption, answer No to proprietary encryption)

---

### Flutter

**`flutter doctor` shows Android licenses not accepted**

```bash
flutter doctor --android-licenses
# Accept all licenses
```

**`flutter pub get` fails with dependency conflicts**

```bash
flutter pub upgrade --major-versions
```

**Build number increment**
- Always increment the build number (`+N` in `pubspec.yaml` version) for each upload. App Store Connect and Play Console reject builds with duplicate build numbers.
- To override without editing `pubspec.yaml`:
  ```bash
  flutter build appbundle --build-name=2.0.0 --build-number=2
  flutter build ipa --build-name=2.0.0 --build-number=2
  ```

---

## Quick Reference

```
org.kharis.app          — bundle ID / package name
kharis-release          — Android keystore alias
android/keystore/kharis-release.jks  — keystore file (NOT committed)
android/key.properties  — signing config (NOT committed)
ios/exportOptions.plist — IPA export config (committed, edit before first build)
lib/core/services/firebase_service.dart → kUseFirebase  — Firebase toggle
```

For store listing copy, screenshots specs, and metadata: see `APP-STORE-LISTING.md`.
For backend Firebase setup details: see `backend/SETUP.md`.
