#!/usr/bin/env bash
# Selects the newest installed Xcode 26+ on a GitHub-hosted macOS runner.
# Orbit targets the iOS 26 SDK, so an older default Xcode can't build it.
set -euo pipefail

newest="$(ls -d /Applications/Xcode_2[6-9]*.app 2>/dev/null | sort -V | tail -n 1 || true)"
if [[ -z "$newest" ]]; then
  echo "No Xcode 26+ found on this runner:" >&2
  ls -d /Applications/Xcode*.app >&2 || true
  exit 1
fi

echo "Selecting $newest"
sudo xcode-select -s "$newest/Contents/Developer"
xcodebuild -version
