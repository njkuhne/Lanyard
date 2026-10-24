import Foundation

/// The parsed contents of servers.yaml.
struct LanyardConfig {
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
}

struct Service: Identifiable {
    let id: Int
    var kind: ServiceKind
    var label: String?
    var icon: String?
    var port: Int?
    var path: String?
    var user: String?
    var https: Bool?
    var url: String?
    var badge: String?  // 1–3 characters shown instead of the icon
    var bundle: String?  // the app an `app` service launches, by bundle identifier
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
