#!/bin/bash
# Runs integration_test/app_polish_walkthrough_test.dart on the iOS simulator
# or the Android emulator, from a fresh install, against the live backend.
#
# The test talks to this script through its log:
#   KSHOT:<name>   capture a host-side screenshot into $SHOTS_DIR/<name>.png
#                  (the test holds the frame ~3 s so the capture lands on it)
#   KACT:<action>  perform a host action the app cannot do itself:
#                    foreground     bring the app back from the browser
#                    dismiss-share  close the OS share sheet
#
# Usage: scripts/run_app_polish_walkthrough.sh ios|android [device-id]
#   ios      default device F7F25682-5CB9-4E69-B116-46F898FF044D
#   android  default device emulator-5554 (must already be booted)
set -uo pipefail

PLATFORM="${1:-}"
BUNDLE="com.kharis.church"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"

case "$PLATFORM" in
  ios) DEVICE="${2:-F7F25682-5CB9-4E69-B116-46F898FF044D}" ;;
  android) DEVICE="${2:-emulator-5554}" ;;
  *)
    echo "usage: $0 ios|android [device-id]" >&2
    exit 64
    ;;
esac

SHOTS_DIR="/tmp/kharis-shots-polish-$PLATFORM"
rm -rf "$SHOTS_DIR"
mkdir -p "$SHOTS_DIR"

ADB="adb"
if ! command -v adb >/dev/null 2>&1 && [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
  ADB="$HOME/Library/Android/sdk/platform-tools/adb"
fi

PUBSPEC_VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1 | tr -d '[:space:]')"

# ── Fresh install + notification permission pre-grant ────────────────────────
# The permission is granted up front so the OS prompt (invisible to the Flutter
# harness) cannot cover the app once onboarding completes. The test still
# proves the app does not *ask* before onboarding: it records every
# Messaging#requestPermission call on the platform channel.
HOST_CAN_DISMISS_SHARE=true
if [ "$PLATFORM" = ios ]; then
  xcrun simctl uninstall "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  if command -v applesimutils >/dev/null 2>&1; then
    applesimutils --byId "$DEVICE" --bundle "$BUNDLE" \
      --setPermissions notifications=YES >/dev/null 2>&1 || true
  else
    echo "warning: applesimutils not found; the OS prompt may appear" >&2
  fi
  # A headless simulator takes no synthetic touches (simctl has no input
  # command), so the native share sheet cannot be closed from the host.
  HOST_CAN_DISMISS_SHARE=false
else
  if "$ADB" -s "$DEVICE" shell pm list packages | grep -q "package:$BUNDLE\$"; then
    "$ADB" -s "$DEVICE" shell pm clear "$BUNDLE" >/dev/null
  fi
  # Grant again once `flutter test` has (re)installed the package.
  (
    for _ in $(seq 1 600); do
      if "$ADB" -s "$DEVICE" shell pm list packages | grep -q "package:$BUNDLE\$"; then
        "$ADB" -s "$DEVICE" shell pm grant "$BUNDLE" \
          android.permission.POST_NOTIFICATIONS >/dev/null 2>&1 && exit 0
      fi
      sleep 1
    done
  ) &
  GRANT_PID=$!
fi

shot() {
  local file="$SHOTS_DIR/$1.png"
  if [ "$PLATFORM" = ios ]; then
    xcrun simctl io "$DEVICE" screenshot "$file" >/dev/null 2>&1
  else
    "$ADB" -s "$DEVICE" exec-out screencap -p >"$file" 2>/dev/null
  fi
}

android_app_focused() {
  "$ADB" -s "$DEVICE" shell dumpsys window 2>/dev/null |
    grep -E 'mCurrentFocus|mFocusedApp' | grep -q "$BUNDLE"
}

host_action() {
  case "$PLATFORM:$1" in
    ios:foreground)
      xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null 2>&1
      ;;
    ios:dismiss-share)
      echo "host: cannot dismiss the iOS share sheet (no input channel to the simulator)"
      ;;
    android:foreground)
      "$ADB" -s "$DEVICE" shell input keyevent KEYCODE_BACK
      sleep 2
      if ! android_app_focused; then
        "$ADB" -s "$DEVICE" shell monkey -p "$BUNDLE" \
          -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
      fi
      ;;
    android:dismiss-share)
      "$ADB" -s "$DEVICE" shell input keyevent KEYCODE_BACK
      ;;
  esac
  echo "host: performed $1"
}

flutter test integration_test/app_polish_walkthrough_test.dart \
  -d "$DEVICE" \
  --dart-define-from-file=env.json \
  --dart-define=PUBSPEC_VERSION="$PUBSPEC_VERSION" \
  --dart-define=HOST_CAN_DISMISS_SHARE="$HOST_CAN_DISMISS_SHARE" \
  --timeout none 2>&1 |
  tee "$SHOTS_DIR/run.log" |
  while IFS= read -r line; do
    printf '%s\n' "$line"
    if [[ "$line" == *KSHOT:* ]]; then
      name="${line##*KSHOT:}"
      name="$(printf '%s' "$name" | tr -cd 'A-Za-z0-9._-')"
      (sleep 1 && shot "$name") &
    elif [[ "$line" == *KACT:* ]]; then
      action="${line##*KACT:}"
      action="$(printf '%s' "$action" | tr -cd 'A-Za-z-')"
      (sleep 1 && host_action "$action") &
    fi
  done
STATUS="${PIPESTATUS[0]}"

if [ -n "${GRANT_PID:-}" ]; then kill "$GRANT_PID" >/dev/null 2>&1 || true; fi

echo
echo "Screenshots: $SHOTS_DIR"
grep -E 'KSTEP:|KCHECK:FAIL|KNOTE:' "$SHOTS_DIR/run.log" >"$SHOTS_DIR/summary.txt" || true
grep -E 'KSTEP:' "$SHOTS_DIR/run.log" | sed 's/.*KSTEP:/  /' || true
exit "$STATUS"
