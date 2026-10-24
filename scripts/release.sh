#!/bin/bash
# Cuts a release: bumps the version, commits, tags vX.Y.Z and pushes. GitHub then
# builds the DMG, writes the release notes and publishes it as the latest release.
# Usage: scripts/release.sh patch|minor|major|X.Y.Z[-suffix]   (a -suffix makes a pre-release)
set -euo pipefail
cd "$(dirname "$0")/.."

ARG="${1:-}"
[[ "$ARG" =~ ^(patch|minor|major|[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?)$ ]] || {
    echo "Usage: $0 patch|minor|major|X.Y.Z[-suffix]" >&2; exit 2; }

[ "$(git branch --show-current)" = "main" ] || { echo "Switch to main first." >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or stash your changes first." >&2; exit 1; }
git fetch -q origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "main isn't in sync with origin; pull or push first." >&2; exit 1; }

SUFFIX=""
BUMP="$ARG"
if [[ "$ARG" == *-* ]]; then BUMP="${ARG%%-*}"; SUFFIX="-${ARG#*-}"; fi
VERSION=$(scripts/bump-version.sh "$BUMP")
TAG="v$VERSION$SUFFIX"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    git checkout -- Lanyard.xcodeproj/project.pbxproj project.yml
    echo "$TAG already exists." >&2; exit 1
fi

git commit -qam "Release $TAG"
git tag -a "$TAG" -m "Lanyard $TAG"
git push -q origin main "$TAG"

echo "Tagged and pushed $TAG. GitHub is building the release:"
sleep 5
gh run list --workflow release.yml --limit 1 --json url --jq '.[0].url' 2>/dev/null || true
