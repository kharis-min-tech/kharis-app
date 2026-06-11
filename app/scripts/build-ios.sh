#!/usr/bin/env bash
# build-ios.sh — Build and export a release IPA for App Store / TestFlight
# Usage: ./scripts/build-ios.sh
# Prerequisites: Flutter, Xcode, valid signing certificates & provisioning profiles
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXPORT_OPTIONS="$PROJECT_ROOT/ios/exportOptions.plist"
OUTPUT_DIR="$PROJECT_ROOT/build/ios/ipa"

echo "==> Changing to project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

echo "==> flutter clean"
flutter clean

echo "==> flutter build ipa (release)"
flutter build ipa --dart-define-from-file=env.json \
  --release \
  --export-options-plist="$EXPORT_OPTIONS"

# Locate the exported .ipa
IPA_PATH=$(find "$OUTPUT_DIR" -name "*.ipa" 2>/dev/null | head -n 1)

if [[ -z "$IPA_PATH" ]]; then
  # Flutter may place it here instead
  IPA_PATH=$(find "$PROJECT_ROOT/build/ios" -name "*.ipa" 2>/dev/null | head -n 1)
fi

echo ""
echo "=================================================="
echo "  Build complete"
echo "  IPA: ${IPA_PATH:-build/ios/**/*.ipa}"
echo "=================================================="
echo ""
echo "Next steps — upload to TestFlight / App Store Connect:"
echo ""
echo "  Option A: Xcode Organizer"
echo "    Open Xcode -> Window -> Organizer -> Archives -> Distribute App"
echo ""
echo "  Option B: xcrun altool (legacy, requires app-specific password)"
echo "    Replace placeholders before running:"
echo ""
# xcrun altool --upload-app \
#   --type ios \
#   --file "${IPA_PATH}" \
#   --username "YOUR_APPLE_ID_EMAIL" \
#   --password "YOUR_APP_SPECIFIC_PASSWORD" \
#   --asc-provider "YOUR_TEAM_ID"
echo ""
echo "  Option C: xcrun notarytool / App Store Connect API key (recommended)"
echo "    See: https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution"
echo ""
echo "  Option D: fastlane deliver"
echo "    fastlane deliver --ipa \"${IPA_PATH:-path/to/Runner.ipa}\""
echo ""
