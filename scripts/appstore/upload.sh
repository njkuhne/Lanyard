#!/bin/bash
# Builds dotlocal for the Mac App Store as a signed .pkg and uploads it to App Store Connect.
#
# Needs in the keychain: "Apple Distribution" and "3rd Party Mac Developer Installer"
# certificates for team WYMF4736GN, plus the "dotlocal Mac App Store" provisioning
# profile installed (double-click it, or copy to ~/Library/Developer/Xcode/UserData/Provisioning Profiles).
#
# To upload, an App Store Connect API key (Developer role is enough):
#   ASC_KEY_ID   the key's ID
#   ASC_ISSUER   the issuer ID shown above the keys list
#   the .p8 at ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8
# Without ASC_KEY_ID it only builds build/appstore/export/dotlocal.pkg.
# Optional: BUILD_NUMBER overrides the build number (each upload needs a new one).
set -euo pipefail
cd "$(dirname "$0")/../.."

OUT=build/appstore
ARCHIVE="$OUT/dotlocal.xcarchive"
rm -rf "$OUT"
EXTRA=()
[ -n "${BUILD_NUMBER:-}" ] && EXTRA+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")

echo "==> Archiving"
# Ad-hoc signed here; the export step re-signs with the distribution certificate and profile.
xcodebuild -project dotlocal.xcodeproj -scheme dotlocal -configuration Release \
    -archivePath "$ARCHIVE" -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=WYMF4736GN \
    "${EXTRA[@]+"${EXTRA[@]}"}" archive 2>&1 | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
[ -d "$ARCHIVE" ] || { echo "Archive failed" >&2; exit 1; }

echo "==> Signing for the App Store"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
    -exportOptionsPlist scripts/appstore/ExportOptions.plist 2>&1 | grep -E "error|EXPORT" || true
PKG="$OUT/export/dotlocal.pkg"
[ -f "$PKG" ] || { echo "Export failed" >&2; exit 1; }
pkgutil --check-signature "$PKG" | head -3

if [ -z "${ASC_KEY_ID:-}" ]; then
    echo "==> Built $PKG (set ASC_KEY_ID and ASC_ISSUER to upload)"; exit 0
fi
echo "==> Validating and uploading"
xcrun altool --validate-app -f "$PKG" -t macos --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER"
xcrun altool --upload-app -f "$PKG" -t macos --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER"
echo "==> Uploaded. It appears in App Store Connect → TestFlight after processing (5–30 min)."
