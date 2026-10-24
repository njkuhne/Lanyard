import AppKit
import SwiftUI
import XCTest
@testable import Lanyard

@MainActor
final class SnapshotTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanyardSnapshots-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func store(_ yaml: String = DemoConfig.text) -> ConfigStore {
        let url = directory.appendingPathComponent("servers.yaml")
        try? yaml.write(to: url, atomically: true, encoding: .utf8)
        return ConfigStore(fileURL: url)
    }

    private func menu(_ store: ConfigStore) -> some View {
        MenuContentView()
            .environmentObject(store)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    private func editor(_ store: ConfigStore, selectedIndex: Int? = nil) -> some View {
        ConfigEditorView(store: store, selectedIndex: selectedIndex)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Dropdown

    func testMenu() {
        assertSnapshot(menu(store()), named: "menu", width: 320)
    }

    func testMenuDark() {
        assertSnapshot(menu(store()), named: "menu-dark", width: 320, appearance: .dark)
    }

    func testMenuEmpty() {
        assertSnapshot(menu(store("servers:\n")), named: "menu-empty", width: 320)
    }

    func testMenuWithConfigError() {
        let store = store()
        try? "servers:\n  - name: Broken\n".write(to: store.fileURL, atomically: true, encoding: .utf8)
        store.reload()
        assertSnapshot(menu(store), named: "menu-error", width: 320)
    }

    private static let crowded = """
    servers:
      - name: The Extremely Long Named Proxmox Cluster Node
        address: pve-node-01.homelab.internal.example.com
        services:
    """ + (1...15).map { "\n          - web: { port: \(8000 + $0), name: App \($0), badge: A\($0) }" }.joined() + """

      - name: Router
        address: 192.168.1.1
        services:
          - web
          - ssh: { badge: SSH }
    """

    func testMenuWithManyServicesAndLongNames() {
        assertSnapshot(menu(store(Self.crowded)), named: "menu-overflow", width: 320)
    }

    func testMenuCompactWithoutAddresses() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: DisplayOption.showAddresses)
        defaults.set(false, forKey: DisplayOption.showServerIcons)
        defer {
            defaults.removeObject(forKey: DisplayOption.showAddresses)
            defaults.removeObject(forKey: DisplayOption.showServerIcons)
        }
        assertSnapshot(menu(store()), named: "menu-compact", width: 320)
    }

    func testAddServerFirstRun() {
        let view = AddServerView(store: store(SampleConfig.starter)).background(Color(nsColor: .windowBackgroundColor))
        assertSnapshot(view, named: "add-server-first-run", width: 440)
    }

    // MARK: Editor

    func testEditorServer() {
        assertSnapshot(editor(store(), selectedIndex: 0), named: "editor-server", width: 780, height: 540)
    }

    func testEditorServerDark() {
        assertSnapshot(editor(store(), selectedIndex: 0), named: "editor-server-dark", width: 780, height: 540, appearance: .dark)
    }

    func testEditorServerWithUsers() {
        assertSnapshot(editor(store(), selectedIndex: 1), named: "editor-server-users", width: 780, height: 540)
    }

    func testEditorDockerHost() {
        assertSnapshot(editor(store(), selectedIndex: 2), named: "editor-docker-host", width: 780, height: 540)
    }

    func testServiceOptionsExpanded() {
        let web = EditorService(kind: .web, port: "9443", label: "Grafana", badge: "GF")
        let ssh = EditorService(kind: .ssh, user: "admin")
        let form = Form {
            Section("Services") {
                ServiceEditor(service: .constant(web), startExpanded: true) {}
                ServiceEditor(service: .constant(ssh), startExpanded: true) {}
            }
        }
        .formStyle(.grouped)
        assertSnapshot(form, named: "service-options", width: 560, height: 420)
    }

    func testEditorDivider() {
        assertSnapshot(editor(store(), selectedIndex: 3), named: "editor-divider", width: 780, height: 540)
    }

    func testEditorYAML() {
        let yaml = YAMLEditorView(store: store()).background(Color(nsColor: .windowBackgroundColor))
        assertSnapshot(yaml, named: "editor-yaml", width: 640, height: 600)
    }

    func testEditorEmpty() {
        assertSnapshot(editor(store("servers:\n")), named: "editor-empty", width: 780, height: 540)
    }

    // MARK: Icon picker

    func testIconPicker() {
        let grid = SymbolGrid(selection: .constant(""), defaultSymbol: "server.rack", isPresented: .constant(true))
            .background(Color(nsColor: .windowBackgroundColor))
        assertSnapshot(grid, named: "icon-picker", width: 340, height: 420)
    }
}
