import Foundation

/// Things the editors need to ask the user, kept behind closures so the logic is testable.
/// The real implementations (alerts and file panels) live in SystemWiring.swift.
struct EditorPrompts {
    var confirmDroppingComments: () -> Bool
    var chooseFileToImport: () -> URL?
    var chooseExportDestination: () -> URL?
}

/// What the Edit Servers window does, minus the drawing.
final class EditorState: ObservableObject {
    @Published var items: [EditorItem] = []
    @Published private(set) var savedItems: [EditorItem] = []
    @Published var selection: EditorItem.ID?
    @Published private(set) var message: String?
    @Published private(set) var messageIsError = false

    let store: ConfigStore
    private let prompts: EditorPrompts

    init(store: ConfigStore, selectedIndex: Int? = nil, prompts: EditorPrompts) {
        self.store = store
        self.prompts = prompts
        load()
        if let selectedIndex, items.indices.contains(selectedIndex) {
            selection = items[selectedIndex].id
        }
    }

    var hasUnsavedChanges: Bool { items != savedItems }

    // MARK: Loading

    func load() {
        let selectedIndex = self.selectedIndex
        items = EditorModel.items(from: store.config)
        savedItems = items
        if let selectedIndex, items.indices.contains(selectedIndex) {
            selection = items[selectedIndex].id
        } else {
            selection = items.first?.id
        }
    }

    /// Picks up outside edits to the file, but never clobbers unsaved work.
    func storeDidChange() {
        if !hasUnsavedChanges { load() }
    }

    func revert() {
        load()
        message = nil
    }

    // MARK: Servers list

    func item(with id: EditorItem.ID) -> EditorItem? {
        items.first { $0.id == id }
    }

    func update(_ item: EditorItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item }
    }

    /// Selects the entry at a position in the config, as the dropdown's "Edit …" does.
    func select(index: Int) {
        if items.indices.contains(index) { selection = items[index].id }
    }

    func addServer() {
        insert(EditorItem(name: "New Server"))
    }

    func addDivider() {
        insert(EditorItem(isDivider: true))
    }

    func deleteSelected() {
        guard let index = selectedIndex else { return }
        items.remove(at: index)
        selection = items.isEmpty ? nil : items[min(index, items.count - 1)].id
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    // MARK: Saving

    /// Returns true if the config was written.
    @discardableResult
    func save() -> Bool {
        if Self.hasComments(store.rawText) && !prompts.confirmDroppingComments() {
            return false
        }
        if let error = store.save(EditorModel.yaml(from: items)) {
            show(error, isError: true)
            return false
        }
        load()
        show("Saved", isError: false)
        return true
    }

    /// The form rewrites the YAML from scratch, so hand-written comments would be lost.
    static func hasComments(_ text: String) -> Bool {
        text.split(separator: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("#") && trimmed != "# Lanyard config"
        }
    }

    // MARK: Private

    private var selectedIndex: Int? {
        selection.flatMap { id in items.firstIndex { $0.id == id } }
    }

    private func insert(_ item: EditorItem) {
        items.insert(item, at: selectedIndex.map { $0 + 1 } ?? items.count)
        selection = item.id
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

/// What the Edit YAML window does, minus the drawing.
final class YAMLEditorState: ObservableObject {
    @Published var text = ""
    @Published private(set) var savedText = ""
    @Published private(set) var message: String?
    @Published private(set) var messageIsError = false

    let store: ConfigStore
    private let prompts: EditorPrompts

    init(store: ConfigStore, prompts: EditorPrompts) {
        self.store = store
        self.prompts = prompts
        load()
    }

    var hasUnsavedChanges: Bool { text != savedText }

    /// Picks up outside edits to the file, but never clobbers unsaved work.
    func storeDidChange() {
        if !hasUnsavedChanges { load() }
    }

    func revert() {
        load()
        message = nil
    }

    /// Returns true if the config was written.
    @discardableResult
    func save() -> Bool {
        if let error = store.save(text) {
            show(error, isError: true)
            return false
        }
        load()
        show("Saved", isError: false)
        return true
    }

    /// Loads a file into the text; nothing is saved until Save.
    func importFile() {
        guard let url = prompts.chooseFileToImport() else { return }
        if let imported = try? String(contentsOf: url, encoding: .utf8) {
            text = imported
            message = nil
        } else {
            show("Couldn't read \(url.lastPathComponent)", isError: true)
        }
    }

    func exportFile() {
        guard let url = prompts.chooseExportDestination() else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            show("Exported to \(url.lastPathComponent)", isError: false)
        } catch {
            show("Couldn't export: \(error.localizedDescription)", isError: true)
        }
    }

    private func load() {
        text = store.rawText
        savedText = text
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

/// The Add Server window: the quickest path to a working server, and the first-run experience.
final class AddServerState: ObservableObject {
    @Published var address = ""
    @Published var name = ""
    @Published private(set) var kinds: Set<ServiceKind> = []
    @Published var webPort = ""
    @Published var webName = ""
    @Published var webBadge = "" {
        didSet { if webBadge.count > 3 { webBadge = String(webBadge.prefix(3)) } }
    }
    /// The name of the server just added; the window shows a confirmation while set.
    @Published private(set) var added: String?
    @Published private(set) var error: String?

    let store: ConfigStore

    init(store: ConfigStore) {
        self.store = store
    }

    var isFirstServer: Bool { store.config.entries.isEmpty }
    var canAdd: Bool { !address.trimmingCharacters(in: .whitespaces).isEmpty && !kinds.isEmpty }

    func toggle(_ kind: ServiceKind) {
        if kinds.contains(kind) { kinds.remove(kind) } else { kinds.insert(kind) }
    }

    /// Appends the server to the file (keeping any comments). Returns true on success.
    @discardableResult
    func add() -> Bool {
        let services = ServiceKind.allCases.filter(kinds.contains).map { kind in
            kind == .web
                ? EditorService(kind: .web, port: webPort, label: webName, badge: webBadge)
                : EditorService(kind: kind)
        }
        let item = EditorItem(name: name, host: address.trimmingCharacters(in: .whitespaces), services: services)
        if let failure = store.save(EditorModel.appending(item, to: store.rawText)) {
            error = failure
            return false
        }
        error = nil
        added = item.listTitle
        return true
    }

    func addAnother() {
        address = ""
        name = ""
        kinds = []
        webPort = ""
        webName = ""
        webBadge = ""
        added = nil
    }
}
