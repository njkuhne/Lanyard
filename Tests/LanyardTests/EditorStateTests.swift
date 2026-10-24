import XCTest
@testable import Lanyard

final class EditorStateTests: XCTestCase {
    private var directory: URL!
    private var confirmAnswer = true
    private var confirmCalls = 0
    private var importURL: URL?
    private var exportURL: URL?

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("LanyardEditor-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private var prompts: EditorPrompts {
        EditorPrompts(
            confirmDroppingComments: { [unowned self] in confirmCalls += 1; return confirmAnswer },
            chooseFileToImport: { [unowned self] in importURL },
            chooseExportDestination: { [unowned self] in exportURL }
        )
    }

    private func store(_ yaml: String = "servers:\n  - name: A\n    address: a\n  - name: B\n    address: b\n") -> ConfigStore {
        let url = directory.appendingPathComponent("servers.yaml")
        try? yaml.write(to: url, atomically: true, encoding: .utf8)
        return ConfigStore(fileURL: url)
    }

    /// Adds a server with an address, so it can be saved.
    private func addNamedServer(_ state: EditorState) {
        state.addServer()
        var item = state.item(with: state.selection!)!
        item.host = "new.lan"
        state.update(item)
    }

    // MARK: Servers editor

    func testStartsOnTheFirstOrRequestedServer() {
        let s = store()
        let first = EditorState(store: s, prompts: prompts)
        XCTAssertEqual(first.item(with: first.selection!)?.name, "A")
        let state = EditorState(store: s, selectedIndex: 1, prompts: prompts)
        XCTAssertEqual(state.item(with: state.selection!)?.name, "B")
        let outOfRange = EditorState(store: s, selectedIndex: 9, prompts: prompts)
        XCTAssertEqual(outOfRange.item(with: outOfRange.selection!)?.name, "A")
        XCTAssertNil(EditorState(store: store("servers:\n"), prompts: prompts).selection)
    }

    func testAddingAndDeleting() {
        let state = EditorState(store: store(), prompts: prompts)
        state.addServer()
        XCTAssertEqual(state.items.map(\.listTitle), ["A", "New Server", "B"])
        state.addDivider()
        XCTAssertEqual(state.items.map(\.listTitle), ["A", "New Server", "Divider", "B"])
        XCTAssertTrue(state.hasUnsavedChanges)

        state.deleteSelected()
        XCTAssertEqual(state.items.map(\.listTitle), ["A", "New Server", "B"])
        XCTAssertEqual(state.item(with: state.selection!)?.listTitle, "B")

        state.selection = nil
        state.addServer()
        XCTAssertEqual(state.items.last?.listTitle, "New Server", "appends when nothing is selected")
        state.selection = nil
        state.deleteSelected()
        XCTAssertEqual(state.items.count, 4, "deleting with no selection does nothing")

        state.items = [state.items[0]]
        state.selection = state.items[0].id
        state.deleteSelected()
        XCTAssertNil(state.selection)
    }

    func testSelectByIndex() {
        let state = EditorState(store: store(), prompts: prompts)
        state.select(index: 1)
        XCTAssertEqual(state.item(with: state.selection!)?.name, "B")
        state.select(index: 7)
        XCTAssertEqual(state.item(with: state.selection!)?.name, "B", "out of range is ignored")
    }

    func testMoveRemoveAndUpdate() {
        let state = EditorState(store: store(), prompts: prompts)
        state.move(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(state.items.map(\.name), ["B", "A"])
        var b = state.items[0]
        b.name = "Bee"
        state.update(b)
        XCTAssertEqual(state.items[0].name, "Bee")
        state.update(EditorItem(name: "Stranger"))
        XCTAssertEqual(state.items.count, 2, "updating an unknown item is ignored")
        state.remove(at: IndexSet(integer: 0))
        XCTAssertEqual(state.items.map(\.name), ["A"])
    }

    func testSaveWritesTheFormAndKeepsSelection() {
        let s = store()
        let state = EditorState(store: s, selectedIndex: 1, prompts: prompts)
        addNamedServer(state)
        XCTAssertTrue(state.save())
        XCTAssertEqual(state.message, "Saved")
        XCTAssertFalse(state.messageIsError)
        XCTAssertFalse(state.hasUnsavedChanges)
        XCTAssertEqual(s.config.entries.count, 3)
        XCTAssertEqual(state.item(with: state.selection!)?.name, "New Server")
        XCTAssertEqual(confirmCalls, 0, "no comments, no question")
    }

    func testSaveAsksBeforeDroppingComments() {
        let s = store("# keep me\nservers:\n  - name: A\n    address: a\n")
        let state = EditorState(store: s, prompts: prompts)
        addNamedServer(state)
        confirmAnswer = false
        XCTAssertFalse(state.save())
        XCTAssertTrue(s.rawText.contains("# keep me"))
        confirmAnswer = true
        XCTAssertTrue(state.save())
        XCTAssertFalse(s.rawText.contains("# keep me"))
        XCTAssertEqual(confirmCalls, 2)
    }

    func testSaveReportsErrors() {
        let state = EditorState(store: store(), prompts: prompts)
        var item = state.items[0]
        item.host = ""
        item.services = [EditorService(kind: .ssh)]
        state.update(item)
        XCTAssertFalse(state.save())
        XCTAssertTrue(state.messageIsError)
        XCTAssertEqual(state.message, "Not saved. A: SSH needs an address, since the server doesn't have one")
    }

    func testHasComments() {
        XCTAssertTrue(EditorState.hasComments("  # note\nservers:\n"))
        XCTAssertFalse(EditorState.hasComments("# Lanyard config\nservers:\n"))
        XCTAssertFalse(EditorState.hasComments("servers:\n"))
    }

    func testRevertAndOutsideChanges() {
        let s = store()
        let state = EditorState(store: s, prompts: prompts)
        state.addServer()
        _ = s.save("servers:\n  - name: C\n    address: c\n")
        state.storeDidChange()
        XCTAssertEqual(state.items.count, 3, "unsaved work is kept")
        state.revert()
        XCTAssertEqual(state.items.map(\.name), ["C"])
        XCTAssertNil(state.message)
        _ = s.save("servers:\n  - name: D\n    address: d\n")
        state.storeDidChange()
        XCTAssertEqual(state.items.map(\.name), ["D"], "clean editors follow the file")
    }

    // MARK: YAML editor

    func testYAMLSaveRevertAndOutsideChanges() {
        let s = store()
        let state = YAMLEditorState(store: s, prompts: prompts)
        XCTAssertEqual(state.text, s.rawText)
        XCTAssertFalse(state.hasUnsavedChanges)

        state.text = "servers:\n  - icon: cpu\n"
        XCTAssertFalse(state.save())
        XCTAssertTrue(state.messageIsError)

        state.text = "servers:\n  - name: Z\n    address: z\n"
        XCTAssertTrue(state.save())
        XCTAssertEqual(state.message, "Saved")
        XCTAssertEqual(s.config.entries.count, 1)
        XCTAssertFalse(state.hasUnsavedChanges)

        _ = s.save("servers:\n")
        state.storeDidChange()
        XCTAssertEqual(state.text, "servers:\n")

        state.text = "edited"
        _ = s.save("servers:\n  - divider\n")
        state.storeDidChange()
        XCTAssertEqual(state.text, "edited", "unsaved work is kept")
        state.revert()
        XCTAssertEqual(state.text, "servers:\n  - divider\n")
        XCTAssertNil(state.message)
    }

    func testImport() throws {
        let state = YAMLEditorState(store: store(), prompts: prompts)
        state.importFile()
        XCTAssertNil(state.message, "cancelled")

        let file = directory.appendingPathComponent("other.yaml")
        try "servers:\n".write(to: file, atomically: true, encoding: .utf8)
        importURL = file
        state.importFile()
        XCTAssertEqual(state.text, "servers:\n")
        XCTAssertTrue(state.hasUnsavedChanges, "importing doesn't save")

        importURL = directory.appendingPathComponent("missing.yaml")
        state.importFile()
        XCTAssertEqual(state.message, "Couldn't read missing.yaml")
        XCTAssertTrue(state.messageIsError)
    }

    func testExport() throws {
        let state = YAMLEditorState(store: store(), prompts: prompts)
        state.exportFile()
        XCTAssertNil(state.message, "cancelled")

        exportURL = directory.appendingPathComponent("backup.yaml")
        state.exportFile()
        XCTAssertEqual(state.message, "Exported to backup.yaml")
        XCTAssertEqual(try String(contentsOf: exportURL!, encoding: .utf8), state.text)

        exportURL = directory.appendingPathComponent("no/such/dir/backup.yaml")
        state.exportFile()
        XCTAssertTrue(state.message?.hasPrefix("Couldn't export") ?? false)
        XCTAssertTrue(state.messageIsError)
    }

    // MARK: Add Server

    func testAddServerFirstRun() {
        let s = store(SampleConfig.starter)
        let state = AddServerState(store: s)
        XCTAssertTrue(state.isFirstServer)
        XCTAssertFalse(state.canAdd)
        state.address = " nas.lan "
        XCTAssertFalse(state.canAdd, "needs at least one service")
        state.address = ""
        state.toggle(.web)
        XCTAssertFalse(state.canAdd, "no address: needs a name and a web address")
        state.name = "Cloud"
        XCTAssertFalse(state.canAdd)
        state.webAddress = "https://dash.example.com"
        XCTAssertTrue(state.canAdd)
        state.toggle(.ssh)
        XCTAssertFalse(state.canAdd, "SSH would have nothing to open")
        state.toggle(.ssh)
        state.toggle(.web)
        state.name = ""
        state.webAddress = ""
        state.address = " nas.lan "
        state.toggle(.web)
        state.toggle(.smb)
        state.toggle(.ssh)
        state.toggle(.ssh)
        XCTAssertEqual(state.kinds, [.web, .smb])
        XCTAssertEqual(state.webPrompt, "https://nas.lan:5001")
        state.webAddress = "https://nas.lan:5001"
        state.webName = "DSM"
        state.webBadge = "DSMX"
        XCTAssertEqual(state.webBadge, "DSM")
        XCTAssertTrue(state.add())
        XCTAssertEqual(state.added, "nas.lan")
        XCTAssertNil(state.error)
        XCTAssertTrue(s.rawText.hasPrefix("# Lanyard"), "comments survive")
        guard case .server(let server) = s.config.entries.first else { return XCTFail("no server") }
        XCTAssertEqual(server.services.map(\.kind), [.web, .smb])
        XCTAssertEqual(server.services[0].url, "https://nas.lan:5001")
        XCTAssertEqual(server.services[0].badge, "DSM")
        XCTAssertFalse(state.isFirstServer)

        state.addAnother()
        XCTAssertNil(state.added)
        XCTAssertEqual(state.address, "")
        XCTAssertTrue(state.kinds.isEmpty)
        XCTAssertEqual(state.webBadge, "")
        XCTAssertEqual(state.webPrompt, "https://nas.local:5001")
    }

    func testAddServerReportsErrors() {
        let s = store("servers:\n  - name: A\n    address: a\n  # trailing comment\n  broken: [\n")
        let state = AddServerState(store: s)
        state.address = "b"
        state.name = "B"
        state.toggle(.ssh)
        XCTAssertFalse(state.add())
        XCTAssertNotNil(state.error)
        XCTAssertNil(state.added)
    }
}
