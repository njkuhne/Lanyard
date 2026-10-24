#!/bin/bash
# Starts the Release workflow on GitHub, which bumps the version, builds the DMG,
# tags, and publishes the release. Usage: scripts/release.sh [patch|minor|major|X.Y.Z]
set -euo pipefail
cd "$(dirname "$0")/.."

BUMP="${1:-patch}"
[[ "$BUMP" =~ ^(patch|minor|major|[0-9]+\.[0-9]+\.[0-9]+)$ ]] || { echo "Usage: $0 [patch|minor|major|X.Y.Z]" >&2; exit 2; }

if [ -n "$(git status --porcelain)" ] || [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}' 2>/dev/null)" ]; then
    echo "Push your changes to main first; the release is built from GitHub's main." >&2
    exit 1
fi

gh workflow run release.yml --ref main -f bump="$BUMP"
sleep 3
echo "Release started: $(gh run list --workflow release.yml --limit 1 --json url --jq '.[0].url')"
echo "Afterwards, pull to get the version bump: git pull"
