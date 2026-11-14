#!/usr/bin/env bash
# Prints an `xcodebuild -destination` value for the first available iPhone
# simulator on the newest installed iOS runtime. Simulator names change
# between runner images, so hard-coding "iPhone 17" would break CI.
set -euo pipefail

xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, re, sys
data = json.load(sys.stdin)["devices"]

def version(runtime):
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)

for runtime in sorted((r for r in data if "iOS" in r), key=version, reverse=True):
    phones = [d for d in data[runtime] if d["name"].startswith("iPhone")]
    if phones:
        print("platform=iOS Simulator,id=" + phones[0]["udid"])
        sys.exit(0)
sys.exit("No available iPhone simulator found")
'
