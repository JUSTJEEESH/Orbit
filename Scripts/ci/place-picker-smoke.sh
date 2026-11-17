#!/usr/bin/env bash
# Runs the Debug app in the simulator with the place-picker harness
# (PlacePickerHarness) and fails if the main thread stalls, UIKit reports a
# layout feedback loop or unsatisfiable constraints, or the app dies early.
# Compile-only CI could not see the device freezes this catches.
#
# Usage: place-picker-smoke.sh [harness-argument] [log-file]
#   harness-argument defaults to -OrbitPlacePickerHarness (the current
#   picker); -OrbitPlacePickerHarnessLegacy runs the old SwiftUI Map picker,
#   which this test is expected to flag.
set -euo pipefail

BUNDLE_ID="com.joshgreen.orbit"
HARNESS_ARG="${1:--OrbitPlacePickerHarness}"
LOG="${2:-picker-smoke.log}"
RUN_SECONDS=35
MIN_HEARTBEATS=10
WARM_UP_SECONDS=10
CPU_SAMPLES=15
# A settled picker idles near 0%; a layout or camera loop pins a core.
MAX_AVERAGE_CPU=60

UDID="$(Scripts/ci/simulator-destination.sh | sed 's/.*id=//')"
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*Build/Products/Debug-iphonesimulator/Orbit.app' -prune | head -1)"
if [ -z "$APP" ]; then
  echo "Built Orbit.app not found"; exit 1
fi
echo "App: $APP"
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location "$BUNDLE_ID" || true
xcrun simctl location "$UDID" set 30.2672,-97.7431 || true

xcrun simctl launch --console-pty --terminate-running-process "$UDID" "$BUNDLE_ID" "$HARNESS_ARG" > "$LOG" 2>&1 &
LAUNCH_PID=$!
sleep "$WARM_UP_SECONDS"

# CPU of the app process after warm-up (simulator apps are host processes).
APP_PID="$(pgrep -f '/Orbit.app/Orbit' | head -1 || true)"
CPU_TOTAL=0
CPU_COUNT=0
if [ -n "$APP_PID" ]; then
  for _ in $(seq 1 "$CPU_SAMPLES"); do
    SAMPLE="$(ps -o %cpu= -p "$APP_PID" 2>/dev/null | tr -d ' ' || true)"
    if [ -n "$SAMPLE" ]; then
      echo "cpu sample: $SAMPLE%"
      CPU_TOTAL="$(echo "$CPU_TOTAL + $SAMPLE" | bc)"
      CPU_COUNT=$((CPU_COUNT + 1))
    fi
    sleep 1
  done
fi
REMAINING=$((RUN_SECONDS - WARM_UP_SECONDS - CPU_SAMPLES))
if [ "$REMAINING" -gt 0 ]; then sleep "$REMAINING"; fi
xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
wait "$LAUNCH_PID" 2>/dev/null || true

echo "---- harness output (filtered) ----"
grep -E "ORBIT_HARNESS|feedback loop|Unable to simultaneously|Fatal|fatal error|Thread [0-9]+ Crashed" "$LOG" | head -60 || true
echo "-----------------------------------"

fail=0
if ! grep -q "ORBIT_HARNESS_PRESENTED" "$LOG"; then
  echo "FAIL: the harness never presented the picker"; fail=1
fi
HEARTBEATS="$(grep -c "ORBIT_HARNESS_ALIVE" "$LOG" || true)"
echo "Heartbeats: $HEARTBEATS (need $MIN_HEARTBEATS)"
if [ "$HEARTBEATS" -lt "$MIN_HEARTBEATS" ]; then
  echo "FAIL: too few heartbeats; the app hung or exited early"; fail=1
fi
if grep -q "ORBIT_HARNESS_HANG" "$LOG"; then
  echo "FAIL: main thread hang detected"; fail=1
fi
if grep -q "Observation tracking feedback loop" "$LOG"; then
  echo "FAIL: UIKit observation feedback loop"; fail=1
fi
if grep -q "Unable to simultaneously satisfy constraints" "$LOG"; then
  echo "FAIL: unsatisfiable layout constraints"; fail=1
fi
if [ "$CPU_COUNT" -gt 0 ]; then
  CPU_AVERAGE="$(echo "scale=1; $CPU_TOTAL / $CPU_COUNT" | bc)"
  echo "Average CPU after warm-up: $CPU_AVERAGE% (limit $MAX_AVERAGE_CPU%)"
  if [ "$(echo "$CPU_AVERAGE > $MAX_AVERAGE_CPU" | bc)" -eq 1 ]; then
    echo "FAIL: the app stayed busy after the map settled (a loop)"; fail=1
  fi
else
  echo "FAIL: could not sample the app's CPU (process not found)"; fail=1
fi
if [ "$fail" -ne 0 ]; then
  echo "---- last 80 lines ----"; tail -80 "$LOG"
fi
exit "$fail"
