enum SampleConfig {
    /// Written on first launch: the format notes and an empty list.
    static let starter = """
# dotlocal — your servers, one click away.
# Changes are picked up automatically when you save this file.
#
# Each server has a name, an address, and a list of services. The order here is
# the order in the menu. Use `- divider` or `- divider: Title` to group them.
#
# Service types: web, smb, nfs, vnc (Screen Sharing), ssh, sftp, app
# Each service opens one address; leave it out to use the server's address:
#   - web: https://nas.local:5001/admin
#   - ssh: ssh://admin@nas.local:2222
#   - smb
#   - app: com.microsoft.rdc.macos      (launches a Mac app)
# Options: name, url, and either icon (any SF Symbol) or badge (1–3 characters).
# Per server: show_address: false and show_icon: false tidy up the menu.

servers: []

"""
}
