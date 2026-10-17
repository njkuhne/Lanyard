#!/usr/bin/env bash
# Quick dev build of build/Lanyard.app without Xcode (no app icon).
# For App Store builds, use the Xcode project (see README).
# Pass --install to copy it to ~/Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Lanyard"

APP="build/Lanyard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Lanyard"
sed -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/net.nickopolis.Lanyard/' \
    -e 's/$(MARKETING_VERSION)/0.1.0-dev/' \
    -e 's/$(CURRENT_PROJECT_VERSION)/1/' \
    -e 's/$(EXECUTABLE_NAME)/Lanyard/' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/13.0/' \
    Resources/Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign - --entitlements Resources/Lanyard.entitlements "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p "$HOME/Applications"
    pkill -x Lanyard 2>/dev/null || true
    rm -rf "$HOME/Applications/Lanyard.app"
    cp -R "$APP" "$HOME/Applications/"
    open "$HOME/Applications/Lanyard.app"
    echo "Installed to ~/Applications/Lanyard.app"
fi
