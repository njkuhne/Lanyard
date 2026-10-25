import Foundation

/// The parsed contents of servers.yaml.
struct DotlocalConfig {
    var entries: [Entry] = []
}

/// One row in the menu: a server or a divider.
enum Entry: Identifiable {
    case server(Server)
    case divider(id: Int, title: String?)

    var id: Int {
        switch self {
        case .server(let server): return server.id
        case .divider(let id, _): return id
        }
    }
}

struct Server: Identifiable {
    let id: Int
    var name: String
    var host: String
    var icon: String?
    var services: [Service]
    var showAddress = true
    var showIcon = true

    var hasAddress: Bool { !host.trimmingCharacters(in: .whitespaces).isEmpty }
    /// The address line under the name: shown only when there is one and it's wanted.
    var showsAddressLine: Bool { showAddress && hasAddress }
    var tooltip: String { hasAddress ? "\(name) — \(host)" : name }
}

struct Service: Identifiable {
    let id: Int
    var kind: ServiceKind
    var label: String?
    var icon: String?
    /// Where it opens, e.g. `ssh://admin@nas.local:2222`. Empty means the server's address.
    var url: String?
    var badge: String?  // 1–3 characters shown instead of the icon
    var bundle: String?  // the app an `app` service launches, by bundle identifier
}

/// The Appearance setting: follow the system, or force light or dark.
enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    static let defaultsKey = "appearance"

    init(stored: String?) {
        self = stored.flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The AppKit appearance to force, or nil to follow the system.
    var appearanceName: String? {
        switch self {
        case .system: return nil
        case .light: return "NSAppearanceNameAqua"
        case .dark: return "NSAppearanceNameDarkAqua"
        }
    }
}

/// Line breaking for a row of service buttons: fill each line, then wrap.
enum FlowRows {
    /// Indexes of the items on each line, given item widths and the space available.
    static func rows(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var x: CGFloat = 0
        for (index, width) in widths.enumerated() {
            if !current.isEmpty && x + width > maxWidth {
                rows.append(current)
                current = []
                x = 0
            }
            current.append(index)
            x += width + spacing
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}
