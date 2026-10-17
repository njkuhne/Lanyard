# Handoff: start here

Notes from the previous session (Claude in the Claude app, Oct 17 2026) for
whoever picks this up in Claude Code. Read `CLAUDE.md` too: that's the
standing project guide; this file is the "where we left off".

## Where things stand

- All code, the Xcode project, the placeholder icon, README and LICENSE are written.
- **Nothing has ever been compiled.** The previous session ran in a Linux VM
  and couldn't run Xcode. Expect some compile errors.
- `Lanyard.xcodeproj/project.pbxproj` was **hand-generated**, not made by Xcode.
  If Xcode refuses to open it or behaves oddly, regenerate it with XcodeGen
  (`brew install xcodegen && xcodegen generate`, using `project.yml`) instead
  of debugging the pbxproj by hand.
- Git may not be initialised yet. If `git status` fails, run
  `git init && git add -A && git commit -m "Lanyard v0.1 (uncompiled)"`
  before changing anything, so there's a baseline to diff against.

## Do this first, in order

1. Build with the `xcodebuild` command in `CLAUDE.md`. Fix errors and rebuild
   until it's clean. Fix new warnings where it's cheap.
2. Launch the app. Check that:
   - a server-rack icon appears in the menu bar, with no Dock icon;
   - the dropdown shows the sample servers from the generated `servers.yaml`;
   - clicking a web icon opens the browser and an smb icon opens Finder;
   - **Edit Servers…** opens the editor window, both tabs work, and saving
     updates the dropdown.
3. Commit once it builds and runs.
4. Then tell Nick what you fixed and anything that didn't behave as described.

## Things most likely to need attention

- **Yams return types**: `ConfigParser` expects mappings as `[String: Any]` or
  `[AnyHashable: Any]` and handles both. If parsing comes back empty, check what
  `Yams.load` actually returns.
- **Sandbox**: the config path resolves inside the container, so it's under
  `~/Library/Containers/net.nickopolis.Lanyard/…`, not `~/Library/Application Support`.
  `NSWorkspace.open` for `ssh://`, `vnc://` and `smb://` should still work from
  the sandbox. Verify that it does.
- **The editor window** is an AppKit `NSWindow` hosting SwiftUI
  (`EditorWindow.swift`). Because the app is an accessory app, check that it
  actually comes to the front and takes keyboard focus.
- **macOS 14+ deprecations** (`onChange` with one parameter,
  `.menuStyle(.borderlessButton)`, `NSApp.activate(ignoringOtherApps:)`) are
  warnings only. The deployment target is macOS 13, so don't "fix" them in a
  way that breaks 13.
- `ConfigStore.pasteFromClipboard()` / `importFromFile()` are no longer wired to
  any UI (the YAML tab replaced them). Delete them or leave them, your call.

## About Nick

- Director of Product Management, with an iOS development background. He's
  comfortable with Xcode and Swift but wants things to just work.
- He wants Lanyard to appeal to homelab people: open source, YAML config, and
  sold on the Mac App Store.
- His own servers to test with:
  - `nas.nickopolis.net` (Synology: web UI + file sharing)
  - `Pseudoserver` (Mac mini: Screen Sharing + file sharing)

## After v0.1 runs

These were discussed but not decided. Ask Nick before starting any of them:

- `afp` and `ftp` as built-in service types.
- Multiple addresses per server (LAN vs. Tailscale/VPN).
- A real app icon, App Store listing, and signing with his developer team.
