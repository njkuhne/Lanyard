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

/// Turns servers.yaml into a DotlocalConfig, with error messages written for humans.
enum ConfigParser {
    static func parse(_ text: String) throws -> DotlocalConfig {
        let root: Any?
        do {
            root = try Yams.load(yaml: text)
        } catch {
            throw ConfigError("Couldn't read the YAML: \(error)")
        }

        guard let root, !(root is NSNull) else { return DotlocalConfig() } // empty file
        guard let top = dict(root) else {
            throw ConfigError("The file should start with `servers:`")
        }
        guard let rawList = top["servers"] else {
            throw ConfigError("Missing a `servers:` list")
        }
        if rawList is NSNull { return DotlocalConfig() }
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
                throw ConfigError("\(position) should be a server (with a `name:` or `address:`) or `- divider`")
            }

            if fields.keys.contains("divider") {
                entries.append(.divider(id: nextID(), title: string(fields["divider"])))
                continue
            }

            // `host:` is the older name for `address:`. The address is optional when
            // every service says where it opens; then the server needs a name.
            let host = (string(fields["address"]) ?? string(fields["host"]) ?? "").trimmingCharacters(in: .whitespaces)
            let givenName = string(fields["name"])?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !givenName.isEmpty || !host.isEmpty else {
                throw ConfigError("\(position): needs a `name:` or an `address:`")
            }
            let name = givenName.isEmpty ? host : givenName

            var services: [Service] = []
            if let raw = fields["services"], !(raw is NSNull) {
                guard let rawServices = raw as? [Any] else {
                    throw ConfigError("\(name): `services:` should be a list")
                }
                for rawService in rawServices {
                    services.append(try parseService(rawService, server: name, host: host, nextID: nextID))
                }
            }

            entries.append(.server(Server(
                id: nextID(),
                name: name,
                host: host,
                icon: string(fields["icon"]),
                services: services,
                showAddress: bool(fields["show_address"]) ?? true,
                showIcon: bool(fields["show_icon"]) ?? true
            )))
        }
        return DotlocalConfig(entries: entries)
    }

    /// Services can be written as:
    ///   - ssh                                   (opens the server's address)
    ///   - web: https://nas.local:5001/admin     (where it opens)
    ///   - ssh: { url: "ssh://admin@nas.local:2222", name: Shell, badge: SH }
    ///   - app: com.microsoft.rdc.macos
    /// Older configs with port/path/user/https still load; they're folded into the URL.
    private static func parseService(_ item: Any, server: String, host: String, nextID: () -> Int) throws -> Service {
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
                    options[text.hasPrefix("/") ? "path" : "url"] = text
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

        // `- app: com.example.App` arrives as a url; `app: { bundle: … }` is the long form.
        let bundle = kind == .app ? string(options["bundle"]) ?? string(options.removeValue(forKey: "url")) : nil
        if kind == .app && bundle == nil {
            throw ConfigError("\(server): an `app` service needs an app, like `- app: com.microsoft.rdc.macos`")
        }

        let badge = string(options["badge"])
        if let badge, !(1...3).contains(badge.count) {
            throw ConfigError("\(server): badge can be 1–3 characters (“\(badge)” has \(badge.count))")
        }
        if badge != nil && options["icon"] != nil {
            throw ConfigError("\(server): a service shows either an `icon:` or a `badge:`, not both")
        }

        let label = string(options["name"]) ?? string(options["label"])
        let url = string(options["url"]) ?? legacyURL(kind: kind, typeName: typeName, host: host, options: options)
        if host.isEmpty, kind != .app, (url ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            throw ConfigError("\(server): \(label ?? kind.displayName) needs an address, since the server doesn't have one")
        }

        return Service(
            id: nextID(),
            kind: kind,
            label: label,
            icon: string(options["icon"]),
            url: url,
            badge: badge,
            bundle: bundle
        )
    }

    /// Older configs spelled out port, path, user and https; fold them into one URL.
    /// HTTPS was assumed on 443 and common TLS ports, HTTP on any other port.
    private static func legacyURL(kind: ServiceKind, typeName: String, host: String, options: [String: Any]) -> String? {
        guard let scheme = kind.scheme else { return nil }
        let port = int(options["port"])
        let path = string(options["path"])
        let user = string(options["user"])
        var https = bool(options["https"]) ?? bool(options["secure"])
        if typeName.lowercased() == "http" { https = https ?? false }
        guard !host.isEmpty, port != nil || path != nil || user != nil || https != nil else { return nil }

        let tlsPorts: Set<Int> = [443, 5001, 8006, 8443, 9443, 10443, 11443]
        var text = kind == .web ? ((https ?? port.map(tlsPorts.contains) ?? true) ? "https" : "http") : scheme
        text += "://"
        if let user, !user.isEmpty { text += "\(user)@" }
        text += host
        if let port { text += ":\(port)" }
        if let path, !path.isEmpty { text += path.hasPrefix("/") ? path : "/" + path }
        return text
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
