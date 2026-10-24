import Foundation

/// Editable, form-friendly versions of the config, plus a YAML writer.
struct EditorService: Identifiable, Equatable {
    var id = UUID()
    var kind: ServiceKind = .web
    var label = ""
    var icon = ""
    var url = ""
    var badge = ""
    var bundle = ""
}

extension EditorService {
    /// The badge field: at most three characters.
    var badgeInput: String {
        get { badge }
        set { badge = String(newValue.prefix(3)) }
    }

    /// A service shows an icon or a badge, never both: choosing one clears the other.
    var showsBadge: Bool {
        get { !badge.isEmpty }
        set { if newValue { icon = "" } else { badge = "" } }
    }

    var title: String {
        let name = label.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? kind.displayName : name
    }

    /// What a collapsed row shows, so services of the same type can be told apart.
    var summary: String {
        let trimmed = { (s: String) in s.trimmingCharacters(in: .whitespaces) }
        var parts: [String] = []
        if !trimmed(label).isEmpty { parts.append(trimmed(label)) }
        if kind == .app, !trimmed(bundle).isEmpty { parts.append(trimmed(bundle)) }
        if !trimmed(url).isEmpty { parts.append(trimmed(url)) }
        return parts.joined(separator: " · ")
    }
}

struct EditorItem: Identifiable, Equatable {
    var id = UUID()
    var isDivider = false
    var name = ""
    var host = ""
    var icon = ""
    var services: [EditorService] = []
    var showAddress = true
    var showIcon = true

    var listTitle: String {
        if isDivider { return name.isEmpty ? "Divider" : name }
        if !name.isEmpty { return name }
        return host.isEmpty ? "New Server" : host
    }

    /// Another service on this server showing the same badge, which would be ambiguous in the menu.
    /// Moves a service into another's place, as dragging one row onto another does.
    mutating func moveService(_ id: EditorService.ID, to target: EditorService.ID) {
        guard id != target,
              let from = services.firstIndex(where: { $0.id == id }),
              let to = services.firstIndex(where: { $0.id == target }) else { return }
        services.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func badgeClash(for service: EditorService) -> EditorService? {
        guard !service.badge.isEmpty else { return nil }
        return services.first { $0.id != service.id && $0.badge.lowercased() == service.badge.lowercased() }
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
                            label: s.label ?? "",
                            icon: s.icon == s.kind.defaultSymbol ? "" : (s.icon ?? ""),
                            url: s.url ?? "",
                            badge: s.badge ?? "",
                            bundle: s.bundle ?? ""
                        )
                    },
                    showAddress: server.showAddress,
                    showIcon: server.showIcon
                )
            }
        }
    }

    static func yaml(from items: [EditorItem]) -> String {
        let out = "# Lanyard config\nservers:\n"
        if items.isEmpty { return out + "  []\n" }
        return out + items.map(entryYAML).joined()
    }

    /// One entry under `servers:`, followed by a blank line.
    static func entryYAML(_ item: EditorItem) -> String {
        if item.isDivider {
            let title = item.name.trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? "  - divider\n\n" : "  - divider: \(quote(title))\n\n"
        }
        let host = item.host.trimmingCharacters(in: .whitespaces)
        let name = item.name.trimmingCharacters(in: .whitespaces)
        var out = "  - name: \(quote(name.isEmpty ? host : name))\n"
        if !host.isEmpty { out += "    address: \(quote(host))\n" }
        if !item.icon.isEmpty { out += "    icon: \(quote(item.icon))\n" }
        if !item.showAddress { out += "    show_address: false\n" }
        if !item.showIcon { out += "    show_icon: false\n" }
        if !item.services.isEmpty {
            out += "    services:\n"
            for service in item.services {
                out += "      - \(serviceLine(service))\n"
            }
        }
        return out + "\n"
    }

    /// Adds a server to the end of existing YAML without rewriting it, so comments survive.
    static func appending(_ item: EditorItem, to text: String) -> String {
        let entry = entryYAML(item)
        guard let range = text.range(of: #"(?m)^servers:[ \t]*(\[[ \t]*\])?[ \t]*$"#, options: .regularExpression) else {
            let separator = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
            return text + separator + "servers:\n" + entry
        }
        if text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text[..<range.lowerBound] + "servers:\n" + entry
        }
        return text + (text.hasSuffix("\n") ? "" : "\n") + entry
    }

    private static func serviceLine(_ s: EditorService) -> String {
        var options: [String] = []
        func add(_ key: String, _ value: String) {
            let v = value.trimmingCharacters(in: .whitespaces)
            guard !v.isEmpty else { return }
            options.append("\(key): \(Int(v) != nil ? v : quote(v))")
        }
        add("bundle", s.bundle)
        add("url", s.url)
        add("name", s.label)
        add("badge", s.badge)
        add("icon", s.icon)
        // A lone address or app reads best on one line: `- web: https://…`.
        if options.count == 1, let only = options.first, only.hasPrefix("url:") || only.hasPrefix("bundle:"),
           let colon = only.firstIndex(of: ":") {
            return "\(s.kind.rawValue):\(only[only.index(after: colon)...])"
        }
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
