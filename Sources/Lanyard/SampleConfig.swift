enum SampleConfig {
    static let text = """
# Lanyard — your servers, one click away.
# Changes are picked up automatically when you save this file.
#
# Each server has a name, a host, and a list of services. The order here is
# the order in the menu. Use `- divider` or `- divider: Title` to group them.
#
# Service types: web, smb, nfs, vnc (Screen Sharing), ssh, sftp, rdp, custom
# Service options: port, path, user, https, label, icon (any SF Symbol), url
# Web services use HTTPS unless you add `https: false` (or the port is 80).
# In a custom url, {host}, {user} and {port} are filled in for you.

servers:
  - name: NAS
    host: nas.local
    services:
      - web: 5001
      - smb

  - name: Mac mini
    host: mac-mini.local
    services:
      - vnc: { user: admin }
      - smb: { user: admin }
      - ssh: { user: admin }

  - divider: Remote

  - name: VPS
    host: example.com
    services:
      - ssh: { user: root }
      - custom: { url: "https://{host}:9443", icon: shippingbox, label: Portainer }

"""
}
