import Foundation
import Yams

struct ConfigError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }

    /// Error messages use `backticks` for config keys; render them as code.
    static func formatted(_ message: String) -> AttributedString {
        var result = AttributedString()
        for (index, part) in message.split(separator: "`", omittingEmptySubsequences: false).enumerated() {
            var piece = AttributedString(part)
            if index.isMultiple(of: 2) == false { piece.inlinePresentationIntent = .code }
            result += piece
        }
        return result
    }
}

/// Turns servers.yaml into a LanyardConfig, with error messages written for humans.
enum ConfigParser {
    static func parse(_ text: String) throws -> LanyardConfig {
        let root: Any?
        do {
            root = try Yams.load(yaml: text)
        } catch {
            throw ConfigError("Couldn't read the YAML: \(error)")
        }

        guard let root, !(root is NSNull) else { return LanyardConfig() } // empty file
        guard let top = dict(root) else {
            throw ConfigError("The file should start with `servers:`")
        }
        guard let rawList = top["servers"] else {
            throw ConfigError("Missing a `servers:` list")
        }
        if rawList is NSNull { return LanyardConfig() }
        guard let list = rawList as? [Any] else {
            throw ConfigError("`servers:` should be a list, with each item starting with `- `")
        }

        var counter = 0
        func nextID() -> Int {
            counter += 1
            return counter
        }

        var entries: [Entry] = []
        for (index, item) in list.enumerated() {
            let position = "Item \(index + 1) under `servers:`"

            if let word = item as? String {
                guard word.lowercased() == "divider" else {
                    throw ConfigError("\(position): unknown entry “\(word)”. Did you mean `- divider`?")
                }
                entries.append(.divider(id: nextID(), title: nil))
                continue
            }

            guard let fields = dict(item) else {
                throw ConfigError("\(position) should be a server (with `name:` and `address:`) or `- divider`")
            }

            if fields.keys.contains("divider") {
                entries.append(.divider(id: nextID(), title: string(fields["divider"])))
                continue
            }

            // `host:` is the older name for `address:`.
            guard let host = string(fields["address"]) ?? string(fields["host"]), !host.isEmpty else {
                throw ConfigError("\(string(fields["name"]) ?? position): needs an `address:`")
            }
            let name = string(fields["name"]) ?? host

            var services: [Service] = []
            if let raw = fields["services"], !(raw is NSNull) {
                guard let rawServices = raw as? [Any] else {
                    throw ConfigError("\(name): `services:` should be a list")
                }
                for rawService in rawServices {
                    services.append(try parseService(rawService, server: name, nextID: nextID))
                }
            }

            entries.append(.server(Server(
                id: nextID(),
                name: name,
                host: host,
                icon: string(fields["icon"]),
                services: services
            )))
        }
        return LanyardConfig(entries: entries)
    }

    /// Services can be written as:
    ///   - ssh
    ///   - web: 8080                       (port)
    ///   - smb: /photos                    (path)
    ///   - web: https://nas.local:5001     (full URL)
    ///   - web: { port: 8080, https: true }    (HTTPS is assumed only on 443 and common TLS ports)
    ///   - web: { url: "https://{address}:9443/admin", icon: shippingbox, name: Portainer, badge: PT }
    private static func parseService(_ item: Any, server: String, nextID: () -> Int) throws -> Service {
        let typeName: String
        var options: [String: Any] = [:]

        if let word = item as? String {
            typeName = word
        } else if let fields = dict(item) {
            if let type = string(fields["type"]) {
                typeName = type
                options = fields
            } else if fields.count == 1, let entry = fields.first {
                typeName = entry.key
                if let nested = dict(entry.value) {
                    options = nested
                } else if let port = entry.value as? Int {
                    options["port"] = port
                } else if let text = entry.value as? String {
                    options[text.contains("://") ? "url" : "path"] = text
                }
            } else {
                throw ConfigError("\(server): each service needs a type, like `- ssh` or `- web: { port: 8080 }`")
            }
        } else {
            throw ConfigError("\(server): couldn't understand one of the services")
        }

        guard let kind = ServiceKind(alias: typeName) else {
            let known = ServiceKind.allCases.map(\.rawValue).joined(separator: ", ")
            throw ConfigError("\(server): unknown service “\(typeName)”. Known types: \(known)")
        }

        var https = bool(options["https"]) ?? bool(options["secure"])
        if https == nil {
            switch typeName.lowercased() {
            case "http": https = false
            case "https": https = true
            default: break
            }
        }

        let badge = string(options["badge"])
        if let badge, !(1...3).contains(badge.count) {
            throw ConfigError("\(server): badge can be 1–3 characters (“\(badge)” has \(badge.count))")
        }

        let service = Service(
            id: nextID(),
            kind: kind,
            label: string(options["name"]) ?? string(options["label"]),
            icon: string(options["icon"]),
            port: int(options["port"]),
            path: string(options["path"]),
            user: string(options["user"]),
            https: https,
            url: string(options["url"]),
            badge: badge
        )
        return service
    }

    // MARK: - Loose value helpers

    private static func dict(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let s as String: return s
        case let i as Int: return String(i)
        case let d as Double: return String(d)
        default: return nil
        }
    }

    private static func int(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let s = value as? String { return Int(s) }
        return nil
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let s = value as? String {
            switch s.lowercased() {
            case "true", "yes", "on": return true
            case "false", "no", "off": return false
            default: return nil
            }
        }
        return nil
    }
}
