import Foundation

enum ServiceKind: String, CaseIterable {
    case web, smb, nfs, vnc, ssh, sftp, rdp

    /// Accepts the canonical names plus a few friendly aliases.
    init?(alias raw: String) {
        switch raw.lowercased() {
        case "web", "http", "https", "browser", "custom", "link", "url": self = .web
        case "smb", "files", "filesharing", "file-sharing", "fileshare": self = .smb
        case "nfs": self = .nfs
        case "vnc", "screensharing", "screen-sharing", "screen": self = .vnc
        case "ssh", "terminal", "shell": self = .ssh
        case "sftp": self = .sftp
        case "rdp", "remote-desktop", "remotedesktop": self = .rdp
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .web: return "Web"
        case .smb: return "SMB Share"
        case .nfs: return "NFS Share"
        case .vnc: return "Screen Sharing (VNC)"
        case .ssh: return "SSH"
        case .sftp: return "SFTP"
        case .rdp: return "Remote Desktop"
        }
    }

    var usesPath: Bool { [.web, .smb, .nfs, .sftp].contains(self) }
    var usesUser: Bool { [.smb, .vnc, .ssh, .sftp, .rdp].contains(self) }

    /// Short name for the editor's add-service tiles.
    var tileName: String {
        switch self {
        case .web: return "Web"
        case .smb: return "SMB"
        case .nfs: return "NFS"
        case .vnc: return "Screen Sharing"
        case .ssh: return "SSH"
        case .sftp: return "SFTP"
        case .rdp: return "Remote Desktop"
        }
    }

    /// The port the service uses when none is given, shown as a hint in the editor.
    var defaultPort: Int? {
        switch self {
        case .web: return 443
        case .smb: return 445
        case .nfs: return 2049
        case .vnc: return 5900
        case .ssh, .sftp: return 22
        case .rdp: return 3389
        }
    }

    /// Most self-hosted web UIs speak plain HTTP on their own port, so HTTPS is
    /// assumed only for 443 (no port) and ports that are conventionally TLS.
    static let tlsPorts: Set<Int> = [443, 5001, 8006, 8443, 9443, 10443, 11443]

    static func impliesHTTPS(port: Int?) -> Bool {
        guard let port else { return true }
        return tlsPorts.contains(port)
    }

    /// SF Symbol shown in the menu.
    var defaultSymbol: String {
        switch self {
        case .web: return "globe"
        case .smb, .nfs: return "folder"
        case .vnc: return "display"
        case .ssh: return "terminal"
        case .sftp: return "arrow.up.arrow.down.circle"
        case .rdp: return "pc"
        }
    }
}

extension Service {
    var symbol: String { SymbolCatalog.resolved(icon, fallback: kind.defaultSymbol) }
    var title: String { label ?? kind.displayName }

    /// A labelled web link with no custom icon shows its first letter, so several
    /// web UIs on one server don't all look like the same globe.
    var badgeLetter: String? {
        guard icon == nil, kind == .web,
              let first = label?.trimmingCharacters(in: .whitespaces).first else { return nil }
        return String(first).uppercased()
    }

    /// Remote Desktop opens from a .rdp file, the one format Microsoft's app reliably accepts.
    func rdpFile(for server: Server) -> String? {
        guard kind == .rdp else { return nil }
        var address = server.host
        if let port { address += ":\(port)" }
        var lines = ["full address:s:\(address)"]
        if let user, !user.isEmpty { lines.append("username:s:\(user)") }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The URL handed to macOS, which routes each scheme to the right app:
    /// http(s) → browser, smb/nfs → Finder, vnc → Screen Sharing, ssh → Terminal.
    func url(for server: Server) -> URL? {
        let user = self.user

        if let template = url {
            let filled = template
                .replacingOccurrences(of: "{address}", with: server.host)
                .replacingOccurrences(of: "{host}", with: server.host)
                .replacingOccurrences(of: "{user}", with: user ?? "")
                .replacingOccurrences(of: "{port}", with: port.map { String($0) } ?? "")
            return URL(string: filled)
        }

        var components = URLComponents()
        components.host = server.host
        components.port = port
        if let path, !path.isEmpty {
            components.path = path.hasPrefix("/") ? path : "/" + path
        }

        switch kind {
        case .web:
            components.scheme = (https ?? ServiceKind.impliesHTTPS(port: port)) ? "https" : "http"
        case .smb:
            components.scheme = "smb"
            components.user = user
        case .nfs:
            components.scheme = "nfs"
        case .vnc:
            components.scheme = "vnc"
            components.user = user
        case .ssh:
            components.scheme = "ssh"
            components.user = user
        case .sftp:
            components.scheme = "sftp"
            components.user = user
        case .rdp:
            // macOS rejects Microsoft's `rdp://full%20address=s:host` form; see rdpFile(for:).
            return nil
        }
        return components.url
    }
}
