#!/bin/bash
# Runs the release walkthrough integration test on the booted simulator and
# captures a host-side screenshot every time the test prints `KSHOT:<name>`
# (the test holds each marked frame for ~3s so the capture lands on it).
#
# Usage: scripts/run_release_walkthrough.sh [udid]
set -uo pipefail

UDID="${1:-F7F25682-5CB9-4E69-B116-46F898FF044D}"
SHOTS_DIR="/tmp/kharis-shots"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$SHOTS_DIR"
cd "$APP_DIR"

# Pre-grant the notification permission: the native iOS permission alert is
# invisible to the Flutter test harness and would otherwise block the run the
# moment guest sign-in subscribes to FCM topics. Needs wix/brew applesimutils.
if command -v applesimutils >/dev/null 2>&1; then
  applesimutils --byId "$UDID" --bundle com.kharis.app \
    --setPermissions notifications=YES >/dev/null 2>&1 || true
fi

flutter test integration_test/release_walkthrough_test.dart \
  -d "$UDID" \
  --dart-define-from-file=env.json \
  --timeout none 2>&1 \
  | tee "$SHOTS_DIR/run.log" \
  | while IFS= read -r line; do
      printf '%s\n' "$line"
      if [[ "$line" == *KSHOT:* ]]; then
        name="${line##*KSHOT:}"
        name="$(printf '%s' "$name" | tr -cd 'A-Za-z0-9._-')"
        (
          sleep 1
          xcrun simctl io "$UDID" screenshot "$SHOTS_DIR/${name}.png" \
            >/dev/null 2>&1
        ) &
      fi
    done

exit "${PIPESTATUS[0]}"
