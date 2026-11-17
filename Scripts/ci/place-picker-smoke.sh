#!/usr/bin/env bash
# Runs the Debug app in the simulator with the place-picker harness
# (PlacePickerHarness) and fails if the main thread stalls, UIKit reports a
# layout feedback loop or unsatisfiable constraints, or the app dies early.
# Compile-only CI could not see the device freezes this catches.
set -euo pipefail

BUNDLE_ID="com.joshgreen.orbit"
RUN_SECONDS=35
MIN_HEARTBEATS=10
LOG="picker-smoke.log"

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

xcrun simctl launch --console-pty --terminate-running-process "$UDID" "$BUNDLE_ID" -OrbitPlacePickerHarness > "$LOG" 2>&1 &
LAUNCH_PID=$!
sleep "$RUN_SECONDS"
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
if [ "$fail" -ne 0 ]; then
  echo "---- last 80 lines ----"; tail -80 "$LOG"
fi
exit "$fail"
