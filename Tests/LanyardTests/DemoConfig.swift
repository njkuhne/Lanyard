/// A realistic config for snapshot tests.
enum DemoConfig {
    static let text = """
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
      - web: { port: 9443, name: Portainer, badge: PT }
      - web: { port: 3000, name: Grafana }
      - web: { port: 8123, name: Home Assistant }
      - ssh

  - divider: Remote

  - name: VPS
    address: example.com
    services:
      - ssh: { user: root }
      - web: { url: "https://{address}:9443", icon: shippingbox, name: Portainer }

"""
}
