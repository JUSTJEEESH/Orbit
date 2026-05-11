#!/usr/bin/env bash
# Rename Orbit's bundle and App Group identifiers in one shot.
#
# Usage:
#   ./Scripts/rename-identifiers.sh com.joshgreen.orbit group.com.joshgreen.orbit
#
# Pass:
#   $1 — your unique bundle ID prefix (e.g. com.joshgreen.orbit)
#   $2 — your unique App Group identifier (must start with `group.`)
#
# After running:
#   xcodegen generate
#   open Orbit.xcodeproj
#   Select each target → Signing & Capabilities → choose your Team.

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <new-bundle-prefix> <new-app-group-id>"
    echo "Example: $0 com.joshgreen.orbit group.com.joshgreen.orbit"
    exit 1
fi

NEW_BUNDLE="$1"
NEW_GROUP="$2"

OLD_BUNDLE="com.orbit.app"
OLD_GROUP="group.com.orbit.app"

if [[ "$NEW_GROUP" != group.* ]]; then
    echo "Error: App Group identifier must start with 'group.'" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Files where the identifiers appear as string literals.
TARGETS=(
    "project.yml"
    "App/Resources/Orbit.entitlements"
    "Extensions/ShareExtension/Orbit.entitlements"
    "Extensions/OrbitWidgets/Orbit.entitlements"
    "Extensions/ShareExtension/ShareViewController.swift"
    "Extensions/OrbitWidgets/RecentMemoryWidget.swift"
    "Packages/OrbitKit/Sources/OrbitKit/AppConfig.swift"
)

# Use perl for in-place edit that works on both macOS and Linux.
for file in "${TARGETS[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Skipping (not found): $file"
        continue
    fi
    perl -i -pe "s/\Q$OLD_GROUP\E/$NEW_GROUP/g" "$file"
    perl -i -pe "s/\Q$OLD_BUNDLE\E/$NEW_BUNDLE/g" "$file"
    echo "Updated: $file"
done

echo ""
echo "Done. Next:"
echo "  1. xcodegen generate"
echo "  2. open Orbit.xcodeproj"
echo "  3. For each target (Orbit, OrbitShareExtension, OrbitWidgets):"
echo "     Signing & Capabilities → set your Team."
echo "     Xcode will register the new bundle IDs + App Group automatically."
