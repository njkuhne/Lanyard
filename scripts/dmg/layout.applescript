-- Arranges the mounted DMG's Finder window: app on the left, Applications on the
-- right, the arrow background behind them, no toolbar. Usage: osascript layout.applescript "<volume name>"
on run argv
    set volumeName to item 1 of argv
    tell application "Finder"
        tell disk volumeName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {200, 120, 860, 548}
            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 112
            set text size of viewOptions to 13
            set background picture of viewOptions to file ".background:background.tiff"
            set position of item "dotlocal.app" of container window to {165, 180}
            set position of item "Applications" of container window to {495, 180}
            close
            open
            delay 1
            close
        end tell
    end tell
end run
