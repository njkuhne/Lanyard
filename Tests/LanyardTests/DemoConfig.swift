/// A realistic config for snapshot tests.
enum DemoConfig {
    static let text = """
servers:
  - name: NAS
    address: nas.local
    services:
      - web: https://{address}:5001
      - smb

  - name: Mac mini
    address: mac-mini.local
    services:
      - vnc: vnc://admin@{address}
      - smb: smb://admin@{address}
      - ssh: ssh://admin@{address}

  - name: Docker host
    address: docker.local
    services:
      - web: { url: "https://{address}:9443", name: Portainer, badge: PT }
      - web: { url: "http://{address}:3000", name: Grafana, badge: GF }
      - web: { url: "http://{address}:8123", name: Home Assistant, badge: HA }
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
      - ssh: ssh://root@{address}
      - web: { url: "https://{address}:9443", icon: shippingbox, name: Portainer }

"""
}
