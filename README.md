# Lanyard

Your home servers, one click away from the Mac menu bar.

Lanyard lives in the menu bar (no Dock icon). Click it to see your servers, each
with an icon per service. Click an icon and macOS opens the right tool:

| Service | Opens | 
|---|---|
| `web` | your default browser |
| `smb`, `nfs` | Finder (Connect to Server) |
| `vnc` | Screen Sharing |
| `ssh` | Terminal (or your default ssh:// handler) |
| `sftp` | your default sftp:// handler |
| `rdp` | Windows App / Microsoft Remote Desktop |
| `custom` | any URL you like |

Nothing is auto-discovered. You describe your servers in a YAML file you can
version, sync, and share.

## Config

Click **Edit Servers…** in the menu to open the editor. The **Servers** tab is a
form for adding, editing, and drag-reordering servers, services, and dividers.
The **YAML** tab shows the raw config: paste in a whole setup, edit by hand, and
save. Everything is validated before it's saved.

Under the hood it's one file, `servers.yaml`, in Lanyard's Application Support
folder (inside the app's sandbox container). Lanyard also reloads it if it's
changed outside the app.

```yaml
servers:
  - name: NAS
    host: nas.local
    services:
      - web: { port: 5001, https: true }
      - smb

  - name: Mac mini
    host: mac-mini.local
    user: admin
    services: [vnc, smb, ssh]

  - divider: Remote

  - name: VPS
    host: example.com
    services:
      - ssh: { user: root }
      - custom: { url: "https://{host}:9443", icon: shippingbox, label: Portainer }
```

**Servers** take `name`, `host`, and optionally `user` (used by smb, vnc, ssh,
sftp) and `icon` (any SF Symbol name).

**Services** can be written several ways:

```yaml
- ssh                                 # just the type
- web: 8080                           # a port
- smb: /photos                        # a path
- web: https://nas.local:5001/admin   # a full URL
- web: { port: 5001, https: true }    # options
- { type: custom, url: "https://{host}:9443", label: Portainer }
```

Options: `port`, `path`, `user`, `https` (web only), `label` (tooltip), `icon`
(SF Symbol), `url` (overrides everything; `{host}`, `{user}`, `{port}` are filled in).

Friendly aliases work too: `screensharing` = `vnc`, `files` = `smb`, `https` =
web over HTTPS, `terminal` = `ssh`.

Order in the file is order in the menu. `- divider` adds a line;
`- divider: Title` adds a labelled section. Passwords are never stored in the
config — macOS and your Keychain handle those.

## Build

Requires macOS 13+ and Xcode 15+.

```sh
open Lanyard.xcodeproj
```

Press ⌘R. Xcode fetches the one dependency (Yams) on first open. Out of the box
it signs to run locally; to ship, pick your team under Signing & Capabilities,
then Product → Archive.

`project.yml` can regenerate the project with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) if you prefer that workflow,
and `./scripts/build-app.sh --install` builds without opening Xcode.

## License

MIT
