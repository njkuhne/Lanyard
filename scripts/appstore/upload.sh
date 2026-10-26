#!/bin/bash
# Archives dotlocal for the Mac App Store and uploads it to App Store Connect.
#
# Needs an App Store Connect API key with the Admin role (Xcode uses it to make
# the distribution certificate and provisioning profile for you):
#   ASC_KEY_ID   the key's ID
#   ASC_ISSUER   the issuer ID shown above the keys list
#   ASC_KEY      path to the .p8 (default: ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8)
# Optional: BUILD_NUMBER overrides the build number (each upload needs a new one).
set -euo pipefail
cd "$(dirname "$0")/../.."

: "${ASC_KEY_ID:?Set ASC_KEY_ID}" "${ASC_ISSUER:?Set ASC_ISSUER}"
ASC_KEY="${ASC_KEY:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
[ -f "$ASC_KEY" ] || { echo "No API key at $ASC_KEY" >&2; exit 1; }

OUT=build/appstore
ARCHIVE="$OUT/dotlocal.xcarchive"
rm -rf "$OUT"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY"
      -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER")
EXTRA=()
[ -n "${BUILD_NUMBER:-}" ] && EXTRA+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")

echo "==> Archiving"
xcodebuild -project dotlocal.xcodeproj -scheme dotlocal -configuration Release \
    -archivePath "$ARCHIVE" -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=WYMF4736GN CODE_SIGN_IDENTITY="Apple Development" \
    "${EXTRA[@]}" "${AUTH[@]}" archive 2>&1 | grep -E "error:|warning:|ARCHIVE (SUCCEEDED|FAILED)" || true
[ -d "$ARCHIVE" ] || { echo "Archive failed" >&2; exit 1; }

echo "==> Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
    -exportOptionsPlist scripts/appstore/ExportOptions.plist "${AUTH[@]}" 2>&1 \
    | grep -vE "^\s*$" | tail -20
echo "==> Uploaded. It shows up in App Store Connect → TestFlight after processing (5–30 min)."
