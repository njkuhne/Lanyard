enum SampleConfig {
    /// Written on first launch: the format notes and an empty list.
    static let starter = """
# Lanyard — your servers, one click away.
# Changes are picked up automatically when you save this file.
#
# Each server has a name, an address, and a list of services. The order here is
# the order in the menu. Use `- divider` or `- divider: Title` to group them.
#
# Service types: web, smb, nfs, vnc (Screen Sharing), ssh, sftp
# Service options: port, path, user, https, badge (1–3 characters), name, icon (any SF Symbol), url
# Web uses HTTPS on 443 and common TLS ports (5001, 8006, 8443, 9443), HTTP on
# any other port. Add `https: true` or `https: false` to say otherwise.
# Give web a full `url` for anything else (another scheme, path or host);
# {address}, {user} and {port} are filled in for you.

servers: []

"""
}
