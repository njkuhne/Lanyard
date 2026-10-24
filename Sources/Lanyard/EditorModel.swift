import Foundation

/// Editable, form-friendly versions of the config, plus a YAML writer.
struct EditorService: Identifiable, Equatable {
    var id = UUID()
    var kind: ServiceKind = .web
    var port = ""
    var path = ""
    var user = ""
    var https = true
    var label = ""
    var icon = ""
    var url = ""
}

struct EditorItem: Identifiable, Equatable {
    var id = UUID()
    var isDivider = false
    var name = ""
    var host = ""
    var icon = ""
    var services: [EditorService] = []

    var listTitle: String {
        if isDivider { return name.isEmpty ? "Divider" : name }
        if !name.isEmpty { return name }
        return host.isEmpty ? "New Server" : host
    }
}

enum EditorModel {
    static func items(from config: LanyardConfig) -> [EditorItem] {
        config.entries.map { entry -> EditorItem in
            switch entry {
            case .divider(_, let title):
                return EditorItem(isDivider: true, name: title ?? "")
            case .server(let server):
                return EditorItem(
                    name: server.name,
                    host: server.host,
                    icon: server.icon ?? "",
                    services: server.services.map { s in
                        EditorService(
                            kind: s.kind,
                            port: s.port.map { String($0) } ?? "",
                            path: s.path ?? "",
                            user: s.user ?? "",
                            https: s.https ?? (s.port != 80),
                            label: s.label ?? "",
                            icon: s.icon == s.kind.defaultSymbol ? "" : (s.icon ?? ""),
                            url: s.url ?? ""
                        )
                    }
                )
            }
        }
    }

    static func yaml(from items: [EditorItem]) -> String {
        var out = "# Lanyard config\nservers:\n"
        if items.isEmpty { return out + "  []\n" }
        for item in items {
            if item.isDivider {
                let title = item.name.trimmingCharacters(in: .whitespaces)
                out += title.isEmpty ? "  - divider\n\n" : "  - divider: \(quote(title))\n\n"
                continue
            }
            let host = item.host.trimmingCharacters(in: .whitespaces)
            let name = item.name.trimmingCharacters(in: .whitespaces)
            out += "  - name: \(quote(name.isEmpty ? host : name))\n"
            out += "    host: \(quote(host))\n"
            if !item.icon.isEmpty { out += "    icon: \(quote(item.icon))\n" }
            if !item.services.isEmpty {
                out += "    services:\n"
                for service in item.services {
                    out += "      - \(serviceLine(service))\n"
                }
            }
            out += "\n"
        }
        return out
    }

    private static func serviceLine(_ s: EditorService) -> String {
        var options: [String] = []
        func add(_ key: String, _ value: String) {
            let v = value.trimmingCharacters(in: .whitespaces)
            guard !v.isEmpty else { return }
            options.append("\(key): \(Int(v) != nil ? v : quote(v))")
        }
        add("url", s.url)
        if s.kind != .custom {
            add("port", s.port)
            add("path", s.path)
            add("user", s.user)
            let impliedHTTPS = s.port.trimmingCharacters(in: .whitespaces) != "80"
            if s.kind == .web && s.https != impliedHTTPS { options.append("https: \(s.https)") }
        }
        add("label", s.label)
        add("icon", s.icon)
        return options.isEmpty ? s.kind.rawValue : "\(s.kind.rawValue): { \(options.joined(separator: ", ")) }"
    }

    /// Leaves simple words bare and double-quotes anything YAML might misread.
    static func quote(_ s: String) -> String {
        let isPlain = s.range(of: #"^[A-Za-z_][A-Za-z0-9 ._/\-]*$"#, options: .regularExpression) != nil
        let reserved = ["true", "false", "yes", "no", "on", "off", "null", "y", "n"].contains(s.lowercased())
        if isPlain && !reserved && !s.hasSuffix(" ") { return s }
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
