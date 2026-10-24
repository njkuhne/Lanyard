#!/bin/bash
# Sets the app version in the Xcode project and project.yml, and bumps the build number.
# Usage: scripts/bump-version.sh patch|minor|major|X.Y.Z   (prints the new version)
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=Lanyard.xcodeproj/project.pbxproj
CURRENT=$(sed -nE 's/.*MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+);/\1/p' "$PROJECT" | head -1)
BUILD=$(sed -nE 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);/\1/p' "$PROJECT" | head -1)
IFS=. read -r MAJOR MINOR PATCH <<<"$CURRENT"

case "${1:-}" in
    patch) NEW="$MAJOR.$MINOR.$((PATCH + 1))" ;;
    minor) NEW="$MAJOR.$((MINOR + 1)).0" ;;
    major) NEW="$((MAJOR + 1)).0.0" ;;
    [0-9]*.[0-9]*.[0-9]*) NEW="$1" ;;
    *) echo "Usage: $0 patch|minor|major|X.Y.Z" >&2; exit 2 ;;
esac
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Not a version: $NEW" >&2; exit 2; }
NEXT_BUILD=$((BUILD + 1))

sed -i '' -E "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = $NEW;/; s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/" "$PROJECT"
sed -i '' -E "s/MARKETING_VERSION: .*/MARKETING_VERSION: $NEW/; s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $NEXT_BUILD/" project.yml
echo "$NEW"
