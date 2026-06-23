#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/.."

echo "=== Kharis Web Build + Deploy ==="
echo ""

cd "$APP_DIR"

# API keys are injected at build time (never baked into the repo).
ENV_FILE="$APP_DIR/env.json"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env.json not found at $ENV_FILE."
  echo "Copy env.example.json to env.json and fill in the keys first."
  exit 1
fi

# --pwa-strategy=none: this app is online-first. The deprecated Flutter service
# worker otherwise caches the app shell and serves a stale build until a later
# reload, which makes deploys look inconsistent. No service worker = every visit
# loads the freshly deployed build.
echo "Step 1/2: Building web (no service worker)..."
flutter build web --pwa-strategy=none --dart-define-from-file=env.json

echo ""
echo "Step 2/2: Deploying to Firebase Hosting (kharis-church)..."
firebase deploy --only hosting --project kharis-church

echo ""
echo "=== Done ==="
echo "Live: https://kharis-church.web.app"
echo "Tip: this is the stable URL. Preview channels (firebase hosting:channel)"
echo "     expire and will show 'page not found' once past their expiry."
