# App Store listing

Source of truth for what's filled in on App Store Connect. Screenshots in this
folder are 2880×1800, rendered by `SCREENSHOTS=1 swift test --filter ScreenshotTests/testAppStore`.

**Name:** dotlocal

**Subtitle** (30 max): Your homelab in the menu bar

**Category:** Utilities (secondary: Developer Tools)

**Price:** Free

**Promotional text** (170 max):
Every server you run, one click away: web UIs, file shares, Screen Sharing and SSH, right from your menu bar.

**Description:**

dotlocal puts your home servers in the menu bar. Add your NAS, Mac mini, Docker host or VPS once, pick the services each one runs, and every one of them is a click away.

Click an icon and dotlocal opens the right tool, pointed at the right server:
• Web dashboards (Synology, Proxmox, Portainer, Home Assistant…) in your browser
• SMB and NFS shares in Finder
• Screen Sharing for your Macs
• SSH and SFTP in your terminal
• Any Mac app, launched with one click

Made for homelab people:
• Point-and-click editor, or paste a whole YAML config. Both write the same file, so it's easy to back up, share or keep in git.
• Short badges like "PT" or "HA" for services that don't have an icon.
• Group servers with dividers, drag to reorder, light and dark mode.
• Launch at login.

Private by design: nothing is discovered, collected or sent anywhere. dotlocal never stores passwords; macOS and your Keychain handle sign-ins.

dotlocal is open source (MIT): github.com/njkuhne/dotlocal

**Keywords** (100 max):
homelab,server,nas,synology,ssh,smb,proxmox,docker,self-hosted,menu bar,launcher,bookmarks,network

**Support URL:** https://github.com/njkuhne/dotlocal/issues

**Marketing URL:** https://github.com/njkuhne/dotlocal

**Privacy policy URL:** https://github.com/njkuhne/dotlocal/blob/main/docs/privacy.md

**App Privacy:** Data Not Collected

**Copyright:** 2026 Nicholas Kuhne

**Age rating:** 4+ (no objectionable content)

**Review notes:**
dotlocal is a menu bar app (no Dock icon). On first launch it opens an Add Server window; enter any name and address (for example "Router" and "192.168.1.1"), pick a service such as Web, and save. The server then appears in the menu under the dotlocal icon in the menu bar, and clicking its icon opens that address in the browser. The gear menu → Edit Servers… adds or edits servers. No account or sign-in is needed.
