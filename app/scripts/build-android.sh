#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/.."

echo "=== Kharis Android Release Build ==="
echo ""

# Verify key.properties exists
KEY_PROPERTIES="$APP_DIR/android/key.properties"
if [[ ! -f "$KEY_PROPERTIES" ]]; then
  echo "ERROR: android/key.properties not found."
  echo "Run scripts/generate-keystore.sh first to create the signing keystore."
  exit 1
fi

cd "$APP_DIR"

echo "Step 1/3: Cleaning previous build..."
flutter clean

echo ""
echo "Step 2/3: Building release App Bundle..."
flutter build appbundle --release --dart-define-from-file=env.json

echo ""
echo "Step 3/3: Build complete."
echo ""

AAB_PATH="$APP_DIR/build/app/outputs/bundle/release/app-release.aab"
echo "=== Output ==="
echo "App Bundle: $AAB_PATH"
echo ""

if [[ -f "$AAB_PATH" ]]; then
  SIZE=$(du -sh "$AAB_PATH" | cut -f1)
  echo "File size: $SIZE"
else
  echo "WARNING: Expected .aab not found at $AAB_PATH — check build output above."
fi

echo ""
echo "=== Next Steps (Google Play Console) ==="
echo "1. Go to https://play.google.com/console"
echo "2. Select or create the Kharis app (package: com.kharis.church)"
echo "3. Navigate to: Release > Production (or Internal testing)"
echo "4. Click 'Create new release' and upload: $AAB_PATH"
echo "5. Fill in release notes and roll out"
