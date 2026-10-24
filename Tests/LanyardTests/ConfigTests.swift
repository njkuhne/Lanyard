import XCTest
@testable import Lanyard

final class ConfigParserTests: XCTestCase {
    private func parseError(_ yaml: String) -> String? {
        do {
            _ = try ConfigParser.parse(yaml)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func servers(_ yaml: String) throws -> [Server] {
        try ConfigParser.parse(yaml).entries.compactMap {
            if case .server(let server) = $0 { return server }
            return nil
        }
    }

    func testEmptyFilesGiveAnEmptyConfig() throws {
        XCTAssertTrue(try ConfigParser.parse("").entries.isEmpty)
        XCTAssertTrue(try ConfigParser.parse("servers:\n").entries.isEmpty)
    }

    func testStructuralErrorsAreReadable() {
        XCTAssertTrue(parseError("servers: [")?.hasPrefix("Couldn't read the YAML") ?? false)
        XCTAssertEqual(parseError("- just a list"), "The file should start with `servers:`")
        XCTAssertEqual(parseError("other: 1"), "Missing a `servers:` list")
        XCTAssertEqual(parseError("servers: 5"), "`servers:` should be a list, with each item starting with `- `")
    }

    func testEntryErrors() {
        XCTAssertEqual(parseError("servers:\n  - banana\n"), "Item 1 under `servers:`: unknown entry “banana”. Did you mean `- divider`?")
        XCTAssertEqual(parseError("servers:\n  - 42\n"), "Item 1 under `servers:` should be a server (with `name:` and `address:`) or `- divider`")
        XCTAssertEqual(parseError("servers:\n  - name: A\n"), "A: needs an `address:`")
        XCTAssertEqual(parseError("servers:\n  - icon: cpu\n"), "Item 1 under `servers:`: needs an `address:`")
        XCTAssertEqual(parseError("servers:\n  - name: A\n    address: a\n    services: ssh\n"), "A: `services:` should be a list")
    }

    func testServiceErrors() {
        let prefix = "servers:\n  - name: A\n    address: a\n    services:\n      - "
        XCTAssertEqual(parseError(prefix + "web: { badge: ABCD }\n"), "A: badge can be 1–3 characters (“ABCD” has 4)")
        XCTAssertNotNil(parseError(prefix + "web: { badge: \"\" }\n"))
        XCTAssertEqual(parseError(prefix + "web: { badge: G, icon: cpu }\n"), "A: a service shows either an `icon:` or a `badge:`, not both")
        XCTAssertEqual(parseError(prefix + "{ port: 1, path: x }\n"), "A: each service needs a type, like `- ssh` or `- web: { port: 8080 }`")
        XCTAssertEqual(parseError(prefix + "[1, 2]\n"), "A: couldn't understand one of the services")
        XCTAssertEqual(parseError(prefix + "gopher\n"), "A: unknown service “gopher”. Known types: web, smb, nfs, vnc, ssh, sftp, app")
        XCTAssertEqual(parseError(prefix + "app\n"), "A: an `app` service needs an app, like `- app: com.microsoft.rdc.macos`")
    }

    func testDividersAndDefaults() throws {
        let config = try ConfigParser.parse("servers:\n  - divider\n  - divider: Remote\n  - address: a.lan\n")
        XCTAssertEqual(config.entries.count, 3)
        guard case .divider(_, nil) = config.entries[0], case .divider(_, "Remote") = config.entries[1],
              case .server(let server) = config.entries[2] else { return XCTFail("unexpected entries") }
        XCTAssertEqual(server.name, "a.lan", "name falls back to the address")
        XCTAssertNotEqual(config.entries[0].id, config.entries[1].id)
        XCTAssertEqual(config.entries[2].id, server.id)
    }

    func testServiceShorthands() throws {
        let yaml = """
        servers:
          - name: A
            address: a
            services:
              - { type: smb, path: /share, secure: yes }
              - smb: /photos
              - web: https://a.lan/x
              - web: { https: "no", name: Admin }
              - web: { https: "on" }
              - web: { https: maybe, port: "8443" }
              - web: { user: nick, path: "" }
              - ssh
              - { name: A, 1: b }
        """
        // The last service is a mapping with a non-string key and no type.
        XCTAssertNotNil(parseError(yaml))
        let services = try servers(yaml.replacingOccurrences(of: "      - { name: A, 1: b }", with: ""))[0].services
        XCTAssertEqual(services.map(\.url), [
            "smb://a/share",
            "smb://a/photos",
            "https://a.lan/x",
            "http://a",
            "https://a",
            "https://a:8443",
            "https://nick@a",
            nil,
        ])
        XCTAssertEqual(services[3].label, "Admin")
    }

    func testNonStringKeysAndNumericNames() throws {
        let server = try servers("servers:\n  - { name: 42, address: 1.5, 7: x }\n")[0]
        XCTAssertEqual(server.name, "42")
        XCTAssertEqual(server.host, "1.5")
    }

    func testErrorFormattingRendersCode() {
        let formatted = ConfigError.formatted("needs an `address:`")
        XCTAssertEqual(String(formatted.characters), "needs an address:")
        let code = formatted.runs.filter { $0.inlinePresentationIntent == .code }
        XCTAssertEqual(code.map { String(formatted[$0.range].characters) }, ["address:"])
        XCTAssertEqual(ConfigError("x").errorDescription, "x")
    }
}

final class ServiceKindTests: XCTestCase {
    private let server = Server(id: 1, name: "Box", host: "box.lan", icon: nil, services: [])

    private func url(_ kind: ServiceKind, _ address: String? = nil) -> String? {
        Service(id: 1, kind: kind, url: address).url(for: server)?.absoluteString
    }

    func testEmptyAddressUsesTheServer() {
        XCTAssertEqual(url(.web), "https://box.lan")
        XCTAssertEqual(url(.web, "  "), "https://box.lan")
        XCTAssertEqual(url(.smb), "smb://box.lan")
        XCTAssertEqual(url(.nfs), "nfs://box.lan")
        XCTAssertEqual(url(.vnc), "vnc://box.lan")
        XCTAssertEqual(url(.ssh), "ssh://box.lan")
        XCTAssertEqual(url(.sftp), "sftp://box.lan")
        XCTAssertNil(url(.app))
    }

    func testAddressesAreUsedAsWritten() {
        XCTAssertEqual(url(.web, "http://grafana.lan:3000/d/home"), "http://grafana.lan:3000/d/home")
        XCTAssertEqual(url(.ssh, "ssh://root@other.lan:2222"), "ssh://root@other.lan:2222")
        XCTAssertEqual(url(.web, "nas.lan:5001"), "https://nas.lan:5001", "no scheme gets the type's own")
        XCTAssertEqual(url(.smb, "box.lan/photos"), "smb://box.lan/photos")
    }

    func testNamesPortsAndFields() {
        for kind in ServiceKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.tileName.isEmpty)
            XCTAssertEqual(kind.scheme == nil, kind == .app)
            XCTAssertFalse(kind.example.isEmpty)
            XCTAssertTrue(SymbolCatalog.isAvailable(kind.defaultSymbol), kind.defaultSymbol)
        }
        XCTAssertEqual(ServiceKind(alias: "Screen-Sharing"), .vnc)
        XCTAssertEqual(ServiceKind(alias: "https"), .web)
        XCTAssertNil(ServiceKind(alias: "gopher"))
    }

    func testTitlesSymbolsAndBadges() {
        let labelled = Service(id: 1, kind: .web, label: " grafana")
        XCTAssertEqual(labelled.title, " grafana")

        XCTAssertEqual(labelled.symbol, "globe")
        XCTAssertEqual(Service(id: 4, kind: .ssh).title, "SSH")
        XCTAssertEqual(Service(id: 5, kind: .ssh, icon: "no.such.symbol").symbol, "terminal")
    }
}

final class SymbolCatalogTests: XCTestCase {
    func testResolvedFallsBackForMissingSymbols() {
        XCTAssertEqual(SymbolCatalog.resolved("cpu", fallback: "x"), "cpu")
        XCTAssertEqual(SymbolCatalog.resolved("no.such.symbol", fallback: "x"), "x")
        XCTAssertEqual(SymbolCatalog.resolved("", fallback: "x"), "x")
        XCTAssertEqual(SymbolCatalog.resolved(nil, fallback: "x"), "x")
    }

    func testSections() {
        let all = SymbolCatalog.sections(matching: " ", defaultSymbol: "globe")
        XCTAssertEqual(all.first?.0, "Default")
        XCTAssertEqual(all.first?.1, ["globe"])
        XCTAssertEqual(all.count, SymbolCatalog.categories.count + 1)

        let byCategory = SymbolCatalog.sections(matching: "storage", defaultSymbol: "globe")
        XCTAssertEqual(byCategory.map(\.0), ["Storage"])

        let bySymbol = SymbolCatalog.sections(matching: "wifi.router", defaultSymbol: "globe")
        XCTAssertEqual(bySymbol.map(\.0), ["Network"])
        XCTAssertTrue(bySymbol[0].1.allSatisfy { $0.contains("wifi.router") })

        XCTAssertTrue(SymbolCatalog.sections(matching: "zzz", defaultSymbol: "globe").isEmpty)
    }
}

final class ConfigStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("LanyardStore-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private var fileURL: URL { directory.appendingPathComponent("Lanyard/servers.yaml") }

    func testCreatesAnEmptyStarterOnFirstLaunch() {
        let store = ConfigStore(fileURL: fileURL)
        XCTAssertEqual(store.rawText, SampleConfig.starter)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.config.entries.isEmpty)
        XCTAssertTrue(store.createdStarterFile)
        XCTAssertFalse(ConfigStore(fileURL: fileURL).createdStarterFile, "only the first launch")
    }

    func testDefaultLocationIsApplicationSupport() {
        XCTAssertTrue(ConfigStore.defaultFileURL.path.hasSuffix("Application Support/Lanyard/servers.yaml"))
    }

    func testBrokenFileKeepsTheLastGoodConfig() throws {
        let store = ConfigStore(fileURL: fileURL)
        _ = store.save(DemoConfig.text)
        try "servers:\n  - name: Oops\n".write(to: fileURL, atomically: true, encoding: .utf8)
        store.reload()
        XCTAssertEqual(store.errorMessage, "Oops: needs an `address:`")
        XCTAssertEqual(store.config.entries.count, 6)
    }

    func testMissingFileIsReported() throws {
        let store = ConfigStore(fileURL: fileURL)
        try FileManager.default.removeItem(at: fileURL)
        store.reload()
        XCTAssertTrue(store.errorMessage?.hasPrefix("Couldn't open") ?? false)
    }

    func testSaveValidatesThenWrites() throws {
        let store = ConfigStore(fileURL: fileURL)
        XCTAssertEqual(store.save("servers:\n  - name: Oops\n"), "Not saved. Oops: needs an `address:`")
        XCTAssertNil(store.save("servers:\n  - name: A\n    address: a\n"))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "servers:\n  - name: A\n    address: a\n")
        XCTAssertEqual(store.config.entries.count, 1)
    }

    func testSaveReportsWriteFailures() throws {
        let store = ConfigStore(fileURL: fileURL)
        try FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        XCTAssertTrue(store.save("servers:\n")?.hasPrefix("Couldn't save") ?? false)
    }

    func testOutsideEditsAreReloaded() throws {
        let store = ConfigStore(fileURL: fileURL)
        try "servers:\n  - name: B\n    address: b\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(5)
        while store.config.entries.count != 1 && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(store.config.entries.count, 1)
    }
}

final class EditorModelTests: XCTestCase {
    func testDefaultsAndTitles() {
        XCTAssertEqual(EditorService().kind, .web)
        XCTAssertEqual(EditorItem().listTitle, "New Server")
        XCTAssertEqual(EditorItem(host: "a.lan").listTitle, "a.lan")
        XCTAssertEqual(EditorItem(isDivider: true).listTitle, "Divider")
        XCTAssertEqual(EditorItem(isDivider: true, name: "Remote").listTitle, "Remote")
    }

    func testSummary() {
        XCTAssertEqual(EditorService(kind: .web, label: "Portainer", url: "https://nas:9443").summary, "Portainer · https://nas:9443")
        XCTAssertEqual(EditorService(kind: .ssh).summary, "")
        XCTAssertEqual(EditorService(kind: .web, label: "Admin", url: "https://a.lan/x").summary, "Admin · https://a.lan/x")
    }

    func testYAMLWriterCoversEveryShape() throws {
        let items = [
            EditorItem(isDivider: true),
            EditorItem(isDivider: true, name: "Remote"),
            EditorItem(name: "", host: "a.lan", icon: "cpu", services: [
                EditorService(kind: .ssh, icon: "terminal.fill", url: "ssh://root@a.lan:2222"),
                EditorService(kind: .web, url: "https://a.lan:5001"),
                EditorService(kind: .web, label: "yes", badge: "Y"),
            ]),
        ]
        let yaml = EditorModel.yaml(from: items)
        XCTAssertTrue(yaml.contains("  - divider\n"))
        XCTAssertTrue(yaml.contains("  - divider: Remote\n"))
        XCTAssertTrue(yaml.contains("  - name: a.lan\n    address: a.lan\n    icon: cpu\n"))
        XCTAssertTrue(yaml.contains("- ssh: { url: \"ssh://root@a.lan:2222\", icon: terminal.fill }"))
        XCTAssertTrue(yaml.contains("- web: \"https://a.lan:5001\"\n"), "a lone address is written on one line")
        XCTAssertTrue(yaml.contains("- web: { name: \"yes\", badge: \"Y\" }"), "reserved words are quoted")
        XCTAssertEqual(EditorModel.yaml(from: []), "# Lanyard config\nservers:\n  []\n")
        XCTAssertEqual(try ConfigParser.parse(yaml).entries.count, 3)
    }

    func testQuoting() {
        XCTAssertEqual(EditorModel.quote("nas.local"), "nas.local")
        XCTAssertEqual(EditorModel.quote("a: b"), "\"a: b\"")
        XCTAssertEqual(EditorModel.quote("say \"hi\" \\ bye"), "\"say \\\"hi\\\" \\\\ bye\"")
        XCTAssertEqual(EditorModel.quote("trailing "), "\"trailing \"")
    }

    func testDividersBareServicesAndDisplaySettingsRoundTrip() throws {
        let config = try ConfigParser.parse("""
        servers:
          - divider
          - name: A
            address: a
            show_address: false
            show_icon: no
            services:
              - ssh
          - name: B
            address: b
        """)
        let items = EditorModel.items(from: config)
        XCTAssertEqual(items[0].name, "")
        XCTAssertFalse(items[1].showAddress)
        XCTAssertFalse(items[1].showIcon)
        XCTAssertTrue(items[2].showAddress)
        XCTAssertTrue(items[2].showIcon)
        let yaml = EditorModel.yaml(from: items)
        XCTAssertTrue(yaml.contains("    show_address: false\n    show_icon: false\n"))
        XCTAssertTrue(yaml.contains("      - ssh\n"))
        XCTAssertEqual(yaml.components(separatedBy: "show_address").count, 2, "only written when hidden")
    }

    func testLoadingDropsIconsThatMatchTheDefault() throws {
        let config = try ConfigParser.parse("servers:\n  - name: A\n    address: a\n    services:\n      - web: { icon: globe }\n")
        XCTAssertEqual(EditorModel.items(from: config)[0].services[0].icon, "")
    }
}

final class BadgeAndLayoutTests: XCTestCase {
    func testBadgeInputIsCappedAtThree() {
        var service = EditorService(kind: .ssh)
        service.badgeInput = "ABCDE"
        XCTAssertEqual(service.badgeInput, "ABC")
    }

    func testIconOrBadgeAndTitle() {
        var service = EditorService(kind: .ssh, icon: "cpu")
        XCTAssertFalse(service.showsBadge)
        service.showsBadge = true
        XCTAssertEqual(service.icon, "", "choosing a badge clears the icon")
        service.badge = "SH"
        XCTAssertTrue(service.showsBadge)
        service.showsBadge = false
        XCTAssertEqual(service.badge, "", "choosing an icon clears the badge")
        XCTAssertEqual(EditorService(kind: .ssh, label: " Shell ").title, "Shell")
        XCTAssertEqual(EditorService(kind: .ssh).title, "SSH")
    }

    func testBadgeClash() {
        let grafana = EditorService(kind: .web, label: "Grafana", badge: "G")
        let gitea = EditorService(kind: .web, label: "gitea", badge: "g")
        let shell = EditorService(kind: .ssh)
        let item = EditorItem(services: [grafana, gitea, shell])
        XCTAssertEqual(item.badgeClash(for: gitea)?.id, grafana.id)
        XCTAssertNil(item.badgeClash(for: shell))
        XCTAssertNil(EditorItem(services: [grafana]).badgeClash(for: grafana))
    }

    func testFlowRowsWrap() {
        XCTAssertEqual(FlowRows.rows(widths: [], maxWidth: 100, spacing: 2), [])
        XCTAssertEqual(FlowRows.rows(widths: [26, 26, 26], maxWidth: 100, spacing: 2), [[0, 1, 2]])
        XCTAssertEqual(FlowRows.rows(widths: [26, 26, 26, 26], maxWidth: 100, spacing: 2), [[0, 1, 2], [3]])
        XCTAssertEqual(FlowRows.rows(widths: [150, 26], maxWidth: 100, spacing: 2), [[0], [1]], "an item wider than the line still gets its own line")
    }

    func testBadgesRoundTrip() throws {
        let config = try ConfigParser.parse("servers:\n  - name: A\n    address: a\n    services:\n      - ssh: { badge: 1 }\n      - web: { label: Old }\n")
        let items = EditorModel.items(from: config)
        XCTAssertEqual(items[0].services[0].badge, "1")
        XCTAssertEqual(items[0].services[1].label, "Old", "label: still loads as the name")
        XCTAssertTrue(EditorModel.yaml(from: items).contains("- ssh: { badge: 1 }"))
    }

    func testAppendingKeepsCommentsAndHandlesEveryStartingPoint() throws {
        let item = EditorItem(name: "NAS", host: "nas.lan", services: [EditorService(kind: .smb)])
        let entry = "  - name: NAS\n    address: nas.lan\n    services:\n      - smb\n\n"
        XCTAssertEqual(EditorModel.appending(item, to: "# hi\nservers: []\n"), "# hi\nservers:\n" + entry)
        XCTAssertEqual(EditorModel.appending(item, to: "servers:"), "servers:\n" + entry)
        XCTAssertEqual(EditorModel.appending(item, to: ""), "servers:\n" + entry)
        XCTAssertEqual(EditorModel.appending(item, to: "# only a comment"), "# only a comment\nservers:\n" + entry)
        let existing = "servers:\n  - name: A\n    address: a"
        XCTAssertEqual(EditorModel.appending(item, to: existing), existing + "\n" + entry)
        XCTAssertEqual(EditorModel.appending(item, to: existing + "\n"), existing + "\n" + entry)
        XCTAssertEqual(try ConfigParser.parse(EditorModel.appending(item, to: SampleConfig.starter)).entries.count, 1)
    }
}

final class AppServiceTests: XCTestCase {
    private let server = Server(id: 1, name: "PC", host: "pc.lan", icon: nil, services: [])

    private func service(_ yaml: String) throws -> Service {
        let config = try ConfigParser.parse("servers:\n  - name: PC\n    address: pc.lan\n    services:\n      - \(yaml)\n")
        guard case .server(let server) = config.entries[0] else { throw ConfigError("no server") }
        return server.services[0]
    }

    func testShortAndLongForms() throws {
        let short = try service("app: com.microsoft.rdc.macos")
        XCTAssertEqual(short.kind, .app)
        XCTAssertEqual(short.bundle, "com.microsoft.rdc.macos")
        XCTAssertNil(short.url(for: server), "no URL: the app is just launched")

        let long = try service("launch: { bundle: com.example.App, url: \"example://pc.lan\", name: Example }")
        XCTAssertEqual(long.bundle, "com.example.App")
        XCTAssertEqual(long.url(for: server)?.absoluteString, "example://pc.lan")
        XCTAssertEqual(long.title, "Example")
        XCTAssertEqual(long.symbol, "app")
    }

    func testEditorRoundTripAndSummary() throws {
        let config = try ConfigParser.parse("servers:\n  - name: PC\n    address: pc.lan\n    services:\n      - app: { bundle: com.example.App, name: Example }\n")
        let items = EditorModel.items(from: config)
        XCTAssertEqual(items[0].services[0].bundle, "com.example.App")
        XCTAssertEqual(items[0].services[0].summary, "Example · com.example.App")
        XCTAssertTrue(EditorModel.yaml(from: items).contains("- app: { bundle: com.example.App, name: Example }"))
        XCTAssertEqual(ServiceKind.app.tileName, "App")
    }
}

final class AppearanceModeTests: XCTestCase {
    func testStoredValues() {
        XCTAssertEqual(AppearanceMode(stored: nil), .system)
        XCTAssertEqual(AppearanceMode(stored: "nonsense"), .system)
        XCTAssertEqual(AppearanceMode(stored: "dark"), .dark)
        XCTAssertEqual(AppearanceMode.allCases.map(\.title), ["System", "Light", "Dark"])
        XCTAssertNil(AppearanceMode.system.appearanceName)
        XCTAssertEqual(AppearanceMode.light.appearanceName, "NSAppearanceNameAqua")
        XCTAssertEqual(AppearanceMode.dark.appearanceName, "NSAppearanceNameDarkAqua")
    }
}
