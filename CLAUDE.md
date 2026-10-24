# Lanyard

> New session? Read `HANDOFF.md` first. It says where the last session left off.

Mac menu bar app for home server / homelab people. You register servers and
the services each one has; the menu shows each server with one icon per
service, and clicking an icon opens the right tool (browser, Finder, Screen
Sharing, Terminal…) pointed at that server. Open source (MIT), shipping on the
Mac App Store.

## Build & run

```sh
# Build (no signing needed locally)
xcodebuild -project Lanyard.xcodeproj -scheme Lanyard -configuration Debug \
  -derivedDataPath build/DerivedData build 2>&1 | xcbeautify || true
# (no xcbeautify? drop the pipe, or: grep -E "error:|warning:")

# Run the built app
open build/DerivedData/Build/Products/Debug/Lanyard.app

# Quit a running copy before relaunching
pkill -x Lanyard
```

After any change: build, fix every error, and re-build until clean before
reporting done. Treat new warnings as worth fixing too.

## Snapshot tests

```sh
swift test                      # compare UI against Tests/LanyardTests/__Snapshots__
RECORD_SNAPSHOTS=1 swift test   # re-record after an intended UI change, then review the PNGs
```

Tests run through SwiftPM because an Xcode-hosted test runs inside the
sandboxed app and can't write reference images into the repo. A mismatch
writes the actual image to `build/snapshot-failures/`. The reference PNGs double
as screenshots of each flow (menu, editor states, icon picker, light and dark).
`swift build` also catches APIs newer than macOS 13, which the Xcode build
didn't until its deployment-target override was removed.

## Releasing

`scripts/make-dmg.sh` builds a universal Release app and `build/Lanyard-<version>.dmg`
(`VERSION=0.2.0` overrides the version). Unsigned unless `DEVELOPER_ID` is set;
notarizes with `NOTARY_PROFILE` or `NOTARY_KEY`/`NOTARY_KEY_ID`/`NOTARY_ISSUER`.
The DMG window layout (background with arrow, icon positions) is applied by
`scripts/dmg/layout.applescript` via Finder; if Finder automation is refused it
falls back to a plain folder window. `scripts/dmg/background.svg` is the source
for the committed 1x/2x PNGs. `.github/workflows/ci.yml` runs tests, coverage
and a DMG on every push to main and on PRs; `.github/workflows/release.yml` publishes a GitHub release for every pushed tag
(`-suffix` tags are pre-releases; others are marked Latest), with notes from
`scripts/release-notes.py` (commits since the previous tag). `scripts/release.sh
patch|minor|major|X.Y.Z` bumps the version (`scripts/bump-version.sh`), commits,
tags and pushes; the Actions-tab Run workflow does the same on GitHub (logic tests only on CI,
since snapshot images vary by machine) and attaches the DMG to the release.
Nick has no Developer ID Application certificate yet (only Development and
Apple Distribution, team WYMF4736GN), so DMGs are unsigned until he makes one.

## README screenshots

`docs/screenshots/` is rendered by `Tests/LanyardTests/ScreenshotTests.swift`: the
real views placed on a neutral desktop with a menu bar and window chrome, using
the demo config (never a real one). Regenerate with
`SCREENSHOTS=1 swift test --filter ScreenshotTests`; it's skipped otherwise.

## Coverage

```sh
scripts/coverage.sh   # runs the tests; fails unless every logic file is at 100% line coverage
```

Three kinds of code, held to different bars:

- **Logic, 100% line coverage:** `ConfigParser`, `ConfigStore`, `EditorModel`,
  `EditorState`, `Model`, `ServiceKind`, `SymbolCatalog`. Keep decisions here
  (and out of views) so they stay testable; add a file to `LOGIC` in the
  script when it holds logic.
- **Views, snapshot-tested:** `MenuContentView`, `ConfigEditorView`,
  `YAMLEditorView`, `SymbolPicker`. Their bodies render in the snapshot tests;
  button actions are one-line calls into the logic above.
- **System wiring, excluded:** `LanyardApp` (`@main`), `EditorWindow` (NSWindow
  and the save prompt), `LoginItem` (SMAppService), `SystemWiring` (alerts, file
  panels, NSWorkspace, pasteboard, `Launcher`). These only do anything with a
  person at the screen; the logic deciding when to call them is tested through
  `EditorPrompts` fakes.

## Project status

- v0.1 was written without ever being compiled. **First job: get a clean build.**
- Then launch it and check the menu bar icon, the dropdown, and Edit Servers….

## How it works

- `Sources/Lanyard/LanyardApp.swift` — `@main`, `MenuBarExtra` with `.window` style.
  Dock icon hidden via `LSUIElement` in `Resources/Info.plist` and `.accessory` policy.
- `ConfigStore.swift` — owns `servers.yaml` in Application Support (inside the
  sandbox container: `~/Library/Containers/net.nickopolis.Lanyard/Data/Library/Application Support/Lanyard/servers.yaml`).
  Creates a sample on first launch, watches the file and reloads on change,
  validates before every save, keeps the last good config if the file is broken.
- `ConfigParser.swift` — YAML → model via Yams, with human-readable errors.
  Each service is a type plus one address (`- web: https://nas.local:5001`,
  `- ssh: ssh://admin@nas.local:2222`, bare `- smb` uses the server's address;
  addresses are used as written, with no placeholders),
  a name, and either an icon or a 1–3 character badge. Older configs with
  port/path/user/https still load and are folded into the URL; `custom`/`link`
  are aliases for web; `host:` is the old name for `address:`. Servers can set
  `show_address: false` / `show_icon: false`.
- `Model.swift`, `ServiceKind.swift` — model; each service turns into a URL
  handed to `NSWorkspace.open`, which routes it to the right app. An `app`
  service launches a Mac app by bundle ID instead.
- `MenuContentView.swift` — the dropdown: server rows, service icon buttons,
  dividers, error banner, and a gear menu (Edit Servers…, Appearance, Launch at Login, About, Quit).
- `ConfigEditorView.swift` + `EditorState` — the Edit Servers window (form,
  drag to reorder, servers, dividers, services). Saving writes YAML with
  `EditorModel.yaml(from:)`, which drops comments, so it asks first.
- `YAMLEditorView.swift` + `YAMLEditorState` — the separate Edit YAML window, opened by the Edit YAML… button in Edit Servers
  (raw text, Import…/Export…).
- `EditorWindow.swift` — one AppKit window controller per editor, with the
  unsaved-changes prompt.

## Decisions (keep these)

- **Mac App Store app**, so it stays **sandboxed** (`Resources/Lanyard.entitlements`).
  Don't read config from `~/.config` or anywhere outside the container.
- **YAML is the source of truth**; the GUI editor reads and writes the same file.
  Users must be able to paste a whole config in and save it.
- Nothing is auto-discovered; everything is user-configured.
- One host per server for v1 (no LAN vs VPN address switching yet).
- Never store passwords — usernames at most; macOS/Keychain handle credentials.
- macOS 13+ minimum. SwiftUI first, AppKit where SwiftUI falls short.
- Only dependency is Yams. Ask before adding another.

## Ideas not built yet

- `afp` and `ftp` as first-class service types (work today as a web `url:`).
- Multiple addresses per server (LAN / Tailscale / external).
- Reachability dot per server.
- Keyboard navigation in the dropdown; global hotkey to open it.
- Real app icon (the current one in `Resources/Assets.xcassets` is a placeholder).

## Files you can ignore

- `Package.swift` + `scripts/build-app.sh` — an older SwiftPM build path; the
  Xcode project is canonical. Keep them in sync only if they still build.
- `project.yml` — XcodeGen spec equivalent to the project; optional.
