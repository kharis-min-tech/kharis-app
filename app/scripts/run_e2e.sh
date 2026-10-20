#!/bin/bash
# Runs the on-device journeys (integration_test/e2e_test.dart) on the iOS
# simulator or the Android emulator, from a fresh install, against the live
# backends, then prints a summary table and exits non-zero on any FAIL.
#
# Usage: scripts/run_e2e.sh ios|android [journey ...]
#   journeys: onboarding branch_switch events messages player playlists bible
#             giving forms deep_links display account more_menu notifications
#   (none = all)
#
# Environment:
#   E2E_DEVICE  device id (default: iOS F7F25682-5CB9-4E69-B116-46F898FF044D,
#               Android: the first emulator, booting AVD $E2E_AVD if none)
#   E2E_AVD     Android AVD to boot when no emulator runs (Pixel_10_Pro_XL)
#   E2E_SEED    seed for the run's random choices (default: today, YYYYMMDD)
#
# The test talks to this script through its log:
#   KSHOT:<journey>/<name>  screenshot into $OUT/<journey>/<name>.png
#   KJOURNEY:<id>:<PASS|FAIL|SKIP>:<ms>:<detail>  one line per journey
set -uo pipefail

PLATFORM="${1:-}"
shift || true
JOURNEYS=("$@")
BUNDLE="com.kharis.church"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"

SDK="$HOME/Library/Android/sdk"
ADB="adb"
command -v adb >/dev/null 2>&1 || ADB="$SDK/platform-tools/adb"

case "$PLATFORM" in
  ios | android) ;;
  *)
    echo "usage: $0 ios|android [journey ...]" >&2
    exit 64
    ;;
esac

OUT="/tmp/kharis-e2e-$PLATFORM"
rm -rf "$OUT"
mkdir -p "$OUT"
LOG="$OUT/run.log"
SEED="${E2E_SEED:-$(date +%Y%m%d)}"
PUBSPEC_VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1 | tr -d '[:space:]')"
JOURNEY_CSV="$(IFS=,; echo "${JOURNEYS[*]:-}")"
STARTED=$(date +%s)

# ── Device ───────────────────────────────────────────────────────────────────
if [ "$PLATFORM" = ios ]; then
  DEVICE="${E2E_DEVICE:-F7F25682-5CB9-4E69-B116-46F898FF044D}"
  if ! xcrun simctl list devices | grep "$DEVICE" | grep -q Booted; then
    echo "booting simulator $DEVICE"
    xcrun simctl boot "$DEVICE" || exit 1
  fi
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null || exit 1
else
  DEVICE="${E2E_DEVICE:-$("$ADB" devices | awk '/^emulator-[0-9]+\tdevice$/{print $1; exit}')}"
  if [ -z "$DEVICE" ]; then
    AVD="${E2E_AVD:-Pixel_10_Pro_XL}"
    echo "booting AVD $AVD"
    nohup "$SDK/emulator/emulator" -avd "$AVD" -no-snapshot-save -no-boot-anim \
      >"$OUT/emulator.log" 2>&1 &
    "$ADB" wait-for-device
    DEVICE="$("$ADB" devices | awk '/^emulator-[0-9]+\tdevice$/{print $1; exit}')"
  fi
  for _ in $(seq 1 180); do
    [ "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
    sleep 2
  done
fi
echo "platform $PLATFORM, device $DEVICE, seed $SEED, journeys ${JOURNEY_CSV:-all}"

# ── Fresh install + notification permission pre-grant ────────────────────────
# The OS prompt is invisible to the Flutter harness and would cover the app;
# the onboarding journey still proves the app only *asks* after onboarding
# (it records every requestPermission call on the messaging channel).
if [ "$PLATFORM" = ios ]; then
  xcrun simctl uninstall "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  if command -v applesimutils >/dev/null 2>&1; then
    applesimutils --byId "$DEVICE" --bundle "$BUNDLE" \
      --setPermissions notifications=YES >/dev/null 2>&1 || true
  else
    echo "warning: applesimutils not found; the notification prompt may cover the app" >&2
  fi
else
  "$ADB" -s "$DEVICE" uninstall "$BUNDLE" >/dev/null 2>&1 || true
  (
    for _ in $(seq 1 900); do
      if "$ADB" -s "$DEVICE" shell pm list packages 2>/dev/null | grep -q "package:$BUNDLE\$"; then
        "$ADB" -s "$DEVICE" shell pm grant "$BUNDLE" \
          android.permission.POST_NOTIFICATIONS >/dev/null 2>&1 && exit 0
      fi
      sleep 1
    done
  ) &
  GRANT_PID=$!
fi

shot() {
  local file="$OUT/$1.png"
  mkdir -p "$(dirname "$file")"
  if [ "$PLATFORM" = ios ]; then
    xcrun simctl io "$DEVICE" screenshot "$file" >/dev/null 2>&1
  else
    "$ADB" -s "$DEVICE" exec-out screencap -p >"$file" 2>/dev/null
  fi
}

# ── Run ──────────────────────────────────────────────────────────────────────
ALL=(onboarding branch_switch events messages player playlists bible giving
  forms deep_links display account more_menu notifications media_focus)
[ ${#JOURNEYS[@]} -gt 0 ] && ALL=("${JOURNEYS[@]}")

# One process per batch. A journey that trips a framework invariant (e.g. a
# duplicate GlobalKey) leaves that process's widget tree unusable, so the
# journeys after it report DEFER and run again here in a fresh process.
run_batch() {
  flutter test integration_test/e2e_test.dart \
    -d "$DEVICE" \
    --dart-define-from-file=env.json \
    --dart-define=JOURNEYS="$1" \
    --dart-define=E2E_SEED="$SEED" \
    --dart-define=PUBSPEC_VERSION="$PUBSPEC_VERSION" \
    --timeout none 2>&1 |
    tee -a "$LOG" |
    while IFS= read -r line; do
      printf '%s\n' "$line"
      if [[ "$line" == *KSHOT:* ]]; then
        name="${line##*KSHOT:}"
        name="$(printf '%s' "$name" | tr -cd 'A-Za-z0-9._/-')"
        (sleep 0.5 && shot "$name") &
      fi
    done
  return "${PIPESTATUS[0]}"
}

: >"$LOG"
STATUS=0
BATCH="$JOURNEY_CSV"
for attempt in 1 2 3 4 5; do
  before="$(grep -cE 'KJOURNEY:[a-z_]+:(PASS|FAIL|SKIP):' "$LOG")"
  run_batch "$BATCH" || STATUS=$?
  after="$(grep -cE 'KJOURNEY:[a-z_]+:(PASS|FAIL|SKIP):' "$LOG")"
  # Deferred, or never reported (the framework can fail a test before its
  # body runs once the tree is corrupted).
  DEFERRED=()
  for id in "${ALL[@]}"; do
    grep -qE "KJOURNEY:$id:(PASS|FAIL|SKIP):" "$LOG" || DEFERRED+=("$id")
  done
  [ ${#DEFERRED[@]} -eq 0 ] && break
  if [ "$after" -eq "$before" ]; then
    echo "no journey reported in the last batch; not retrying ${DEFERRED[*]}"
    break
  fi
  BATCH="$(IFS=,; echo "${DEFERRED[*]}")"
  echo "rerunning in a fresh process (attempt $((attempt + 1))): $BATCH" | tee -a "$OUT/reruns.txt"
done
[ -n "${GRANT_PID:-}" ] && kill "$GRANT_PID" >/dev/null 2>&1
wait 2>/dev/null

# ── Summary ──────────────────────────────────────────────────────────────────
SUMMARY="$OUT/summary.txt"
FAILED=0
printf '\n%-15s %-6s %9s  %s\n' JOURNEY RESULT DURATION DETAIL >"$SUMMARY"
printf '%-15s %-6s %9s  %s\n' --------------- ------ --------- ------ >>"$SUMMARY"
for id in "${ALL[@]}"; do
  row="$(grep -E "KJOURNEY:$id:(PASS|FAIL|SKIP):" "$LOG" | tail -n1 | sed 's/.*KJOURNEY://')"
  if [ -z "$row" ]; then
    result=FAIL ms=0 detail="no result (the test process stopped before this journey reported)"
  else
    IFS=: read -r _ result ms detail <<<"$row"
  fi
  [ "$result" = FAIL ] && FAILED=$((FAILED + 1))
  printf '%-15s %-6s %8ss  %.200s\n' "$id" "$result" "$((ms / 1000))" "$detail" >>"$SUMMARY"
done
printf '\ntotal %ss on %s (%s), seed %s, screenshots %s\n' \
  "$(($(date +%s) - STARTED))" "$PLATFORM" "$DEVICE" "$SEED" "$OUT" >>"$SUMMARY"
cat "$SUMMARY"
grep -E 'KCHECK:FAIL|KNOTE:' "$LOG" | sed 's/^[^K]*//' >"$OUT/findings.txt" || true

if [ "$FAILED" -gt 0 ] || [ "$STATUS" -ne 0 ]; then
  [ "$FAILED" -eq 0 ] && echo "flutter test exited $STATUS with every journey reported PASS/SKIP; see $LOG"
  exit 1
fi
exit 0
