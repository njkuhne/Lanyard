# Lanyard

Your home servers, one click away from the Mac menu bar.

Lanyard lives in the menu bar (no Dock icon). Click it to see your servers, each
with a button per service. Click a button and macOS opens the right tool:

| Service | Opens |
|---|---|
| `web` | your default browser |
| `smb`, `nfs` | Finder |
| `vnc` | Screen Sharing |
| `ssh` | Terminal (or your default ssh:// handler) |
| `sftp` | your default sftp:// handler |
| `app` | any Mac app, e.g. Windows App for Remote Desktop |

Nothing is auto-discovered. You describe your servers once, and they live in a
YAML file you can keep, sync and share.

## Install

Download `Lanyard-<version>.dmg` from
[Releases](../../releases), open it, and drag Lanyard into Applications.
Requires macOS 13 or later.

## Use

On first launch Lanyard asks for your first server: its address, and what you
open on it. After that, the gear menu has **Edit Servers…** (a form) and
**Edit YAML…** (the raw file; paste a whole setup in). Right-click a server in
the menu to edit just that one, copy its address, or open any of its services.

```yaml
servers:
  - name: NAS
    address: nas.local
    services:
      - web: https://nas.local:5001
      - smb

  - name: Docker host
    address: docker.local
    services:
      - web: { url: "https://{address}:9443", name: Portainer, badge: PT }
      - web: { url: "http://{address}:3000", name: Grafana, badge: GF }
      - ssh: ssh://admin@{address}

  - divider: Remote

  - name: Windows PC
    address: pc.local
    show_address: false
    services:
      - app: com.microsoft.rdc.macos
```

- **Servers** have a `name`, an `address`, an optional `icon` (any SF Symbol),
  and `show_address: false` / `show_icon: false` to tidy the menu.
- **Services** are a type and one address: `- web: https://nas.local:5001/admin`,
  `- ssh: ssh://root@{address}:2222`. Leave the address out (`- smb`) to use the
  server's. `{address}` stands for the server's address.
- Give a service a `name` (tooltips and menus) and either an `icon` or a `badge`
  of 1–3 characters, which is handy when a box runs several web apps.
- `- divider` adds a line, `- divider: Title` a labelled section. Order in the
  file is order in the menu.

Passwords are never stored; macOS and your Keychain handle those. The file is
`servers.yaml` in Lanyard's Application Support folder inside its sandbox
container, and Lanyard reloads it when it changes.

## Build

Requires Xcode 15 or later.

```sh
open Lanyard.xcodeproj     # then ⌘R
swift test                 # tests, including UI snapshot tests
scripts/coverage.sh        # fails unless the logic is 100% covered
scripts/make-dmg.sh        # builds build/Lanyard-<version>.dmg
```

## Releasing

Every push to `main` runs the tests and builds a DMG you can download from the
run's Artifacts. The DMG opens to a window showing Lanyard and an Applications
shortcut to drag it onto.

Push a version tag and GitHub Actions builds the DMG and attaches it to the
release:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

Without signing secrets the DMG is unsigned, and macOS asks people to approve it
in System Settings → Privacy & Security on first open. To ship a DMG that opens
cleanly, it needs a **Developer ID Application** certificate and notarization.
Add these repository secrets (details in `.github/workflows/release.yml`):
`DEVELOPER_ID`, `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`,
`NOTARY_KEY_P8`, `NOTARY_KEY_ID` and `NOTARY_ISSUER`.

To sign and notarize locally instead:

```sh
xcrun notarytool store-credentials lanyard-notary   # once
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=lanyard-notary scripts/make-dmg.sh
```

## License

MIT
