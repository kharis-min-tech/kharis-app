#!/usr/bin/env bash
# Builds the Flutter web app and (by default) deploys it to Firebase Hosting.
#
#   ./scripts/build-web.sh               build + deploy to kharis-app-47c49
#   ./scripts/build-web.sh --build-only  build only (exactly what CI runs)
#
# The build command lives only here, so CI (.github/workflows/ci.yml) and a
# local build can never drift apart.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/.."
FIREBASE_PROJECT="kharis-app-47c49"

DEPLOY=1
case "${1:-}" in
  "") ;;
  --build-only) DEPLOY=0 ;;
  *)
    echo "Usage: $0 [--build-only]" >&2
    exit 64
    ;;
esac

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
# reload, which makes deploys look inconsistent. No Flutter service worker =
# every visit loads the freshly deployed build. (web/firebase-messaging-sw.js,
# the push worker, is a separate file and is unaffected.)
echo "=== Kharis web build ==="
flutter build web --release --pwa-strategy=none --dart-define-from-file=env.json

if [[ "$DEPLOY" -eq 0 ]]; then
  echo "Build only: app/build/web"
  exit 0
fi

echo ""
echo "=== Deploying to Firebase Hosting ($FIREBASE_PROJECT) ==="
firebase deploy --only hosting --project "$FIREBASE_PROJECT"

echo ""
echo "=== Done ==="
echo "Live: https://$FIREBASE_PROJECT.web.app"
echo "Tip: this is the stable URL. Preview channels (firebase hosting:channel)"
echo "     expire and will show 'page not found' once past their expiry."
