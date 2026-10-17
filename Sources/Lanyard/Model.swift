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
    var user: String?
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
}
