import Foundation

enum ServiceKind: String, CaseIterable {
    case web, smb, nfs, vnc, ssh, sftp, app

    /// Accepts the canonical names plus a few friendly aliases.
    init?(alias raw: String) {
        switch raw.lowercased() {
        case "web", "http", "https", "browser", "custom", "link", "url": self = .web
        case "smb", "files", "filesharing", "file-sharing", "fileshare": self = .smb
        case "nfs": self = .nfs
        case "vnc", "screensharing", "screen-sharing", "screen": self = .vnc
        case "ssh", "terminal", "shell": self = .ssh
        case "sftp": self = .sftp
        case "app", "application", "launch": self = .app
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
        case .app: return "App"
        }
    }

    /// The URL scheme a bare address gets, or nil for an app.
    var scheme: String? {
        switch self {
        case .web: return "https"
        case .app: return nil
        default: return rawValue
        }
    }

    /// The editor's hint for the address field.
    var example: String {
        switch self {
        case .web: return "https://nas.local:5001/admin"
        case .smb: return "smb://user@nas.local/share"
        case .nfs: return "nfs://nas.local/export"
        case .vnc: return "vnc://user@mac.local"
        case .ssh: return "ssh://user@nas.local:22"
        case .sftp: return "sftp://user@nas.local"
        case .app: return "Optional, e.g. myapp://nas.local"
        }
    }

    /// Short name for the editor's add-service tiles.
    var tileName: String {
        switch self {
        case .web: return "Web"
        case .smb: return "SMB"
        case .nfs: return "NFS"
        case .vnc: return "Screen Sharing"
        case .ssh: return "SSH"
        case .sftp: return "SFTP"
        case .app: return "App"
        }
    }

    /// SF Symbol shown in the menu.
    var defaultSymbol: String {
        switch self {
        case .web: return "globe"
        case .smb, .nfs: return "folder"
        case .vnc: return "display"
        case .ssh: return "terminal"
        case .sftp: return "arrow.up.arrow.down.circle"
        case .app: return "app"
        }
    }
}

extension Service {
    var symbol: String { SymbolCatalog.resolved(icon, fallback: kind.defaultSymbol) }
    var title: String { label ?? kind.displayName }

    /// The URL handed to macOS (or, for an app service, to that app), which routes
    /// each scheme to the right app: http(s) → browser, smb/nfs → Finder,
    /// vnc → Screen Sharing, ssh → Terminal. The address is used as written; with
    /// none, the server's own address opens, and a bare host gets the type's scheme.
    func url(for server: Server) -> URL? {
        let custom = url?.trimmingCharacters(in: .whitespaces) ?? ""
        let host = server.host.trimmingCharacters(in: .whitespaces)
        guard var text = custom.isEmpty ? (host.isEmpty ? nil : kind.scheme.map { "\($0)://\(host)" }) : custom else {
            return nil
        }
        if !text.contains("://"), let scheme = kind.scheme { text = "\(scheme)://\(text)" }
        return URL(string: text)
    }
}
