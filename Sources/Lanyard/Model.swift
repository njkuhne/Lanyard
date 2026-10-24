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
}

/// How many service buttons a dropdown row shows before collapsing the rest.
enum ServiceStrip {
    static let maxButtons = 5

    /// Up to five services all show; beyond that the first four show plus a "+N" button.
    static func split(_ count: Int) -> (visible: Int, hidden: Int) {
        count <= maxButtons ? (count, 0) : (maxButtons - 1, count - maxButtons + 1)
    }
}
