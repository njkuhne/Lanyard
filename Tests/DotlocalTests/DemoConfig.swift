/// A realistic config for snapshot tests.
enum DemoConfig {
    static let text = """
servers:
  - name: NAS
    address: nas.local
    services:
      - web: https://nas.local:5001
      - smb

  - name: Mac mini
    address: mac-mini.local
    services:
      - vnc: vnc://admin@mac-mini.local
      - smb: smb://admin@mac-mini.local
      - ssh: ssh://admin@mac-mini.local

  - name: Docker host
    address: docker.local
    services:
      - web: { url: "https://docker.local:9443", name: Portainer, badge: PT }
      - web: { url: "http://docker.local:3000", name: Grafana, badge: GF }
      - web: { url: "http://docker.local:8123", name: Home Assistant, badge: HA }
      - ssh

  - name: Gaming PC
    address: gaming-pc.local
    services:
      - app: { bundle: com.moonlight-stream.Moonlight, name: Moonlight }
      - smb

  - divider: Remote

  - name: VPS
    address: example.com
    show_address: false
    services:
      - ssh: ssh://root@example.com
      - web: { url: "https://example.com:9443", icon: shippingbox, name: Portainer }

"""
}
