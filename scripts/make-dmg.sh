#!/bin/bash
# Builds dotlocal.app (universal, Release) and packages it as build/dotlocal-<version>.dmg.
#
# VERSION (e.g. 0.2.0) overrides the version in the project; releases set it from the tag.
#
# Unsigned by default, which is fine for testing: macOS will warn on first open.
# For a release people can download, set:
#   DEVELOPER_ID   "Developer ID Application: Your Name (TEAMID)" from your keychain
# and one way to notarize:
#   NOTARY_PROFILE a profile saved with `xcrun notarytool store-credentials`
#   or NOTARY_KEY (path to an App Store Connect .p8), NOTARY_KEY_ID, NOTARY_ISSUER
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=build/release
APP="$BUILD/DerivedData/Build/Products/Release/dotlocal.app"
rm -rf "$BUILD"

SIGNING=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
if [ -n "${DEVELOPER_ID:-}" ]; then
    TEAM=$(sed -E 's/.*\(([A-Z0-9]+)\)$/\1/' <<<"$DEVELOPER_ID")
    SIGNING=(CODE_SIGN_IDENTITY="$DEVELOPER_ID" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM"
             OTHER_CODE_SIGN_FLAGS=--timestamp CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
fi

[ -n "${VERSION:-}" ] && SIGNING+=(MARKETING_VERSION="$VERSION")

echo "==> Building"
xcodebuild -project dotlocal.xcodeproj -scheme dotlocal -configuration Release \
    -derivedDataPath "$BUILD/DerivedData" ONLY_ACTIVE_ARCH=NO "${SIGNING[@]}" \
    build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | grep -v appintentsmetadata || true
[ -d "$APP" ] || { echo "Build failed"; exit 1; }
codesign --verify --deep --strict "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="build/dotlocal-$VERSION.dmg"

echo "==> Packaging $DMG"
VOLUME="dotlocal $VERSION"
STAGE="$BUILD/dmg"
RW="$BUILD/rw.dmg"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# A Retina-ready background: both sizes in one TIFF.
tiffutil -cathidpicheck scripts/dmg/background.png scripts/dmg/background@2x.png \
    -out "$STAGE/.background/background.tiff" >/dev/null 2>&1

# Lay out the window in a writable image, then compress it.
hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || true
hdiutil create -volname "$VOLUME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW" >/dev/null 2>&1
hdiutil attach "$RW" -readwrite -noverify -noautoopen -quiet 2>/dev/null
if ! osascript scripts/dmg/layout.applescript "$VOLUME" 2>/dev/null; then
    echo "Couldn't style the DMG window (Finder automation not allowed); it will open as a plain folder."
fi
rm -rf "/Volumes/$VOLUME/.fseventsd"
sync
hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || hdiutil detach "/Volumes/$VOLUME" -force -quiet 2>/dev/null
rm -f "$DMG"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null 2>&1
rm -f "$RW"

if [ -n "${DEVELOPER_ID:-}" ]; then
    codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        NOTARY=(--keychain-profile "$NOTARY_PROFILE")
    elif [ -n "${NOTARY_KEY:-}" ]; then
        NOTARY=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
    fi
    if [ -n "${NOTARY+x}" ]; then
        echo "==> Notarizing (takes a few minutes)"
        xcrun notarytool submit "$DMG" "${NOTARY[@]}" --wait
        xcrun stapler staple "$DMG"
        spctl --assess --type open --context context:primary-signature --verbose "$DMG"
    else
        echo "Signed but not notarized: set NOTARY_PROFILE or NOTARY_KEY to notarize."
    fi
else
    echo "Unsigned build: macOS will ask people to approve it on first open."
fi

shasum -a 256 "$DMG"
echo "==> $DMG"
