#!/usr/bin/env bash
# deploy-testflight.sh — archive, sign, and upload a TestFlight build autonomously.
#
# Fully autonomous after a one-time setup (no 2FA per deploy). Both signing and
# upload use an App Store Connect API key, so nothing here needs an Apple ID
# logged into Xcode / Xcode's Accounts.
#
# One-time setup (already done for this project — kept for reproducibility):
#   1. developer.apple.com -> Certificates, IDs & Profiles -> Identifiers:
#      register an explicit App ID for `com.kharis.app` (enable Push
#      Notifications for FCM).
#   2. App Store Connect -> Apps -> (+) -> New App for that bundle ID
#      ("Kharis Church App", primary language English (U.K.)).
#   3. App Store Connect -> Users and Access -> Integrations ->
#      App Store Connect API -> generate a Team key with the **Admin** role.
#      Admin is REQUIRED: cloud signing creates the distribution certificate +
#      provisioning profile, which an App Manager key is not allowed to do.
#      Download `AuthKey_<KEYID>.p8` into ~/.appstoreconnect/private_keys/ and
#      note the Key ID + Issuer ID.
#   4. Put the ids in app/.env.deploy (gitignored):
#        ASC_KEY_ID=XXXXXXXXXX
#        ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# After that, EVERY run is autonomous:
#     ./scripts/deploy-testflight.sh            # build number = epoch seconds
#     ./scripts/deploy-testflight.sh 42         # explicit build number
set -euo pipefail

TEAM_ID="Z9TTRH45X3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

# Load deploy credentials (ASC_KEY_ID, ASC_ISSUER_ID).
[[ -f .env.deploy ]] && source .env.deploy
: "${ASC_KEY_ID:?Set ASC_KEY_ID — see one-time setup at the top of this script}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID — see one-time setup at the top of this script}"

KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[[ -f "$KEY_PATH" ]] || { echo "ERROR: API key not found at $KEY_PATH"; exit 1; }

# Monotonic, unique build number so each TestFlight upload is accepted.
BUILD_NUMBER="${1:-$(date +%s)}"
ARCHIVE="build/ios/archive/Runner.xcarchive"

echo "==> Archiving release build $BUILD_NUMBER (flutter)"
# `flutter build ipa` archives and then tries to export the IPA itself. That
# export uses Xcode automatic signing, which has no Apple ID here and therefore
# fails — but the .xcarchive it produces first is exactly what we need, so the
# export failure is expected and ignored. The signed IPA is produced by the
# xcodebuild step below, which authenticates with the ASC API key instead.
rm -rf "$ARCHIVE"
flutter build ipa --release \
  --dart-define-from-file=env.json \
  --build-number="$BUILD_NUMBER" || true
[[ -d "$ARCHIVE" ]] || { echo "ERROR: archive not produced at $ARCHIVE"; exit 1; }

# Guard: some Info.plist omissions pass `altool` validation and upload fine,
# then fail App Store Connect *processing* (build lands in TestFlight as
# "Failed" with no visible reason). Catch the known ones before uploading:
#   CFBundleIconName            -> ITMS-90713
#   NSCalendarsUsageDescription -> ITMS-90683 (add_2_calendar links EventKit)
ARCHIVE_PLIST="$ARCHIVE/Products/Applications/Runner.app/Info.plist"
for key in CFBundleIconName NSCalendarsUsageDescription; do
  plutil -extract "$key" raw -o - "$ARCHIVE_PLIST" >/dev/null 2>&1 || {
    echo "ERROR: $key missing from the built app's Info.plist —"
    echo "       App Store processing would fail. Add it to ios/Runner/Info.plist."
    exit 1
  }
done

echo "==> Exporting signed IPA (xcodebuild cloud signing via ASC API key)"
EXPORT_PLIST="$(mktemp -t kharis_export).plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
</dict>
</plist>
PLIST
rm -rf build/ios/ipa
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath build/ios/ipa \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$KEY_PATH"

IPA="$(find build/ios/ipa -name '*.ipa' 2>/dev/null | head -1)"
[[ -n "$IPA" ]] || { echo "ERROR: no .ipa was produced under build/ios/ipa"; exit 1; }

echo "==> Uploading to TestFlight: $IPA"
# altool exits 0 on some upload failures (e.g. no App Store Connect app record
# matches the bundle id), so trusting its exit status alone reports a success
# that never reached TestFlight. Tee the output and fail on an ERROR line.
UPLOAD_LOG="$(mktemp -t kharis_upload)"
set +e
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | tee "$UPLOAD_LOG"
upload_status=${PIPESTATUS[0]}
set -e

if [[ $upload_status -ne 0 ]] || grep -q "ERROR" "$UPLOAD_LOG"; then
  echo
  echo "ERROR: upload failed — this build did NOT reach TestFlight."
  if grep -q "Cannot determine the Apple ID from Bundle ID" "$UPLOAD_LOG"; then
    BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
      "$ARCHIVE_PLIST" 2>/dev/null || echo unknown)"
    echo
    echo "No App Store Connect app record matches bundle id '$BUNDLE_ID'."
    echo "Cloud signing succeeded, so the App ID and provisioning profile exist;"
    echo "only the App Store Connect app record is missing. Create it at"
    echo "  https://appstoreconnect.apple.com -> Apps -> (+) -> New App"
    echo "using that exact bundle id, then re-run this script. App records"
    echo "cannot be created through the App Store Connect API."
    echo
    echo "Existing records for this team:"
    xcrun altool --list-apps --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" \
      2>/dev/null | grep -E "Name:|Bundle ID:" || true
  fi
  rm -f "$UPLOAD_LOG"
  exit 1
fi
rm -f "$UPLOAD_LOG"

echo "==> Done. Build $BUILD_NUMBER appears in TestFlight after Apple processing (~5-15 min)."
