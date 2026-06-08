#!/usr/bin/env bash
# set-bundle-id.sh — Set iOS/macOS bundle ID and display name
# Usage: ./scripts/set-bundle-id.sh [bundle-id] [display-name]
#   Defaults: org.kharis.app / "Kharis Church"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BUNDLE_ID="${1:-org.kharis.app}"
DISPLAY_NAME="${2:-Kharis Church}"

PBXPROJ="$PROJECT_ROOT/ios/Runner.xcodeproj/project.pbxproj"
INFO_PLIST="$PROJECT_ROOT/ios/Runner/Info.plist"

echo "==> Setting bundle ID: $BUNDLE_ID"
echo "==> Setting display name: $DISPLAY_NAME"

# ── project.pbxproj ────────────────────────────────────────────────────────────
# Replace every PRODUCT_BUNDLE_IDENTIFIER assignment (covers Debug, Release, Profile)
if [[ -f "$PBXPROJ" ]]; then
  sed -i.bak \
    "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" \
    "$PBXPROJ"
  rm -f "${PBXPROJ}.bak"
  echo "    Updated PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj"
else
  echo "    WARNING: $PBXPROJ not found — skipping"
fi

# ── Info.plist — CFBundleDisplayName ──────────────────────────────────────────
if [[ -f "$INFO_PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $DISPLAY_NAME" "$INFO_PLIST"
  echo "    Updated CFBundleDisplayName in Info.plist"

  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFO_PLIST"
  echo "    Updated CFBundleIdentifier in Info.plist"
else
  echo "    WARNING: $INFO_PLIST not found — skipping"
fi

# ── pubspec.yaml — no bundle ID there, but a note ─────────────────────────────
echo ""
echo "==> Done."
echo "    iOS bundle ID  : $BUNDLE_ID"
echo "    Display name   : $DISPLAY_NAME"
echo ""
echo "    Remember to also update:"
echo "      android/app/build.gradle  ->  applicationId \"$(echo "$BUNDLE_ID" | tr '-' '_')\""
echo "      android/app/src/main/AndroidManifest.xml  ->  package attribute (if hardcoded)"
