enum SampleConfig {
    static let text = """
# Lanyard — your servers, one click away.
# Changes are picked up automatically when you save this file.
#
# Each server has a name, an address, and a list of services. The order here is
# the order in the menu. Use `- divider` or `- divider: Title` to group them.
#
# Service types: web, smb, nfs, vnc (Screen Sharing), ssh, sftp, rdp
# Service options: port, path, user, https, label, icon (any SF Symbol), url
# Web uses HTTPS on 443 and common TLS ports (5001, 8006, 8443, 9443), HTTP on
# any other port. Add `https: true` or `https: false` to say otherwise.
# Give web a full `url` for anything else (another scheme, path or host);
# {address}, {user} and {port} are filled in for you.

servers:
  - name: NAS
    address: nas.local
    services:
      - web: 5001
      - smb

  - name: Mac mini
    address: mac-mini.local
    services:
      - vnc: { user: admin }
      - smb: { user: admin }
      - ssh: { user: admin }

  - name: Docker host
    address: docker.local
    services:
      - web: { port: 9443, label: Portainer }
      - web: { port: 3000, label: Grafana }
      - web: { port: 8123, label: Home Assistant }
      - ssh

  - divider: Remote

  - name: VPS
    address: example.com
    services:
      - ssh: { user: root }
      - web: { url: "https://{address}:9443", icon: shippingbox, label: Portainer }

"""
}
