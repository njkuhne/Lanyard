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

    private func store(_ yaml: String = SampleConfig.text) -> ConfigStore {
        let url = directory.appendingPathComponent("servers.yaml")
        try? yaml.write(to: url, atomically: true, encoding: .utf8)
        return ConfigStore(fileURL: url)
    }

    private func menu(_ store: ConfigStore) -> some View {
        MenuContentView()
            .environmentObject(store)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    private func editor(_ store: ConfigStore, tab: ConfigEditorView.Tab = .servers, selectedIndex: Int? = nil) -> some View {
        ConfigEditorView(tab: tab, selectedIndex: selectedIndex)
            .environmentObject(store)
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

    func testEditorDivider() {
        assertSnapshot(editor(store(), selectedIndex: 2), named: "editor-divider", width: 780, height: 540)
    }

    func testEditorYAML() {
        assertSnapshot(editor(store(), tab: .yaml), named: "editor-yaml", width: 780, height: 540)
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
