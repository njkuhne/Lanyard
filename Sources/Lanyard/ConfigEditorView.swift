import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConfigEditorView: View {
    @EnvironmentObject var store: ConfigStore

    enum Tab: Hashable { case servers, yaml }

    @State private var tab: Tab
    @State private var items: [EditorItem] = []
    @State private var savedItems: [EditorItem] = []
    @State private var selection: EditorItem.ID?
    private let initialSelectionIndex: Int?
    private let session: EditorSession?

    init(tab: Tab = .servers, selectedIndex: Int? = nil, session: EditorSession? = nil) {
        _tab = State(initialValue: tab)
        initialSelectionIndex = selectedIndex
        self.session = session
    }
    @State private var yamlText = ""
    @State private var message: String?
    @State private var messageIsError = false

    private var formDirty: Bool { items != savedItems }
    private var yamlDirty: Bool { yamlText != store.rawText }
    private var isDirty: Bool { tab == .servers ? formDirty : yamlDirty }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: Binding(get: { tab }, set: { switchTab(to: $0) })) {
                Text("Servers").tag(Tab.servers)
                Text("YAML").tag(Tab.yaml)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding(.vertical, 10)

            Divider()

            Group {
                switch tab {
                case .servers: serversTab
                case .yaml: yamlTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            bottomBar
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            session?.save = { save() }
            loadFromStore()
            if let index = initialSelectionIndex, items.indices.contains(index) {
                selection = items[index].id
            }
        }
        .onChange(of: formDirty || yamlDirty) { session?.isDirty = $0 }
        .onChange(of: store.rawText) { _ in
            if !formDirty && !yamlDirty { loadFromStore() }
        }
    }

    // MARK: Servers tab

    private var serversTab: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.isDivider ? "minus" : SymbolCatalog.resolved(item.icon, fallback: "server.rack"))
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            Text(item.listTitle)
                                .foregroundStyle(item.isDivider ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .tag(item.id)
                        .listRowSeparator(.hidden)
                    }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { items.remove(atOffsets: $0) }
                }
                .onDeleteCommand(perform: deleteSelected)

                Divider()

                HStack(spacing: 6) {
                    Menu {
                        Button("Add Server") { addServer() }
                        Button("Add Divider") { addDivider() }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()

                    Button {
                        deleteSelected()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selection == nil)

                    Spacer()
                }
                .padding(8)
            }
            .frame(width: 230)

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selection, let item = items.first(where: { $0.id == id }) {
            Group {
                if item.isDivider {
                    DividerEditor(item: binding(for: id))
                } else {
                    ServerEditor(item: binding(for: id))
                }
            }
            .id(id)
        } else {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No servers yet")
                        .font(.title3)
                    Text("Add one here, or paste a whole config into the YAML tab.")
                        .foregroundStyle(.secondary)
                    Button("Add Server", action: addServer)
                        .padding(.top, 6)
                }
            } else {
                Text("Select a server")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func binding(for id: UUID) -> Binding<EditorItem> {
        Binding(
            get: { items.first(where: { $0.id == id }) ?? EditorItem() },
            set: { newValue in
                if let index = items.firstIndex(where: { $0.id == id }) { items[index] = newValue }
            }
        )
    }

    private var insertionIndex: Int {
        if let id = selection, let index = items.firstIndex(where: { $0.id == id }) { return index + 1 }
        return items.count
    }

    private func addServer() {
        let item = EditorItem(name: "New Server")
        items.insert(item, at: insertionIndex)
        selection = item.id
    }

    private func addDivider() {
        let item = EditorItem(isDivider: true)
        items.insert(item, at: insertionIndex)
        selection = item.id
    }

    private func deleteSelected() {
        guard let id = selection, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        selection = items.isEmpty ? nil : items[min(index, items.count - 1)].id
    }

    // MARK: YAML tab

    private var yamlTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste or edit your config. It's checked before it's saved.")
                .font(.callout)
                .foregroundStyle(.secondary)

            CodeEditor(text: $yamlText)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button("Replace with Clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string) { yamlText = text }
                }
                Button("Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(yamlText, forType: .string)
                }
                Button("Open File…") { openFile() }
                Spacer()
            }
            .controlSize(.small)
        }
        .padding(12)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.yaml, .plainText]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            yamlText = text
        } else {
            show("Couldn't read \(url.lastPathComponent)", isError: true)
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack {
            if let message {
                Label(message, systemImage: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(messageIsError ? Color.orange : Color.green)
                    .font(.callout)
                    .lineLimit(3)
            } else if tab == .servers {
                Text("Saving from this tab rewrites the YAML, which drops comments.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Revert") {
                loadFromStore()
                message = nil
            }
            .disabled(!formDirty && !yamlDirty)

            Button("Save") { save() }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!isDirty)
        }
        .padding(12)
    }

    // MARK: Actions

    private func loadFromStore() {
        let selectedIndex = selection.flatMap { id in items.firstIndex(where: { $0.id == id }) }
        items = EditorModel.items(from: store.config)
        savedItems = items
        yamlText = store.rawText
        if let selectedIndex, items.indices.contains(selectedIndex) {
            selection = items[selectedIndex].id
        } else {
            selection = items.first?.id
        }
    }

    private func switchTab(to newTab: Tab) {
        guard newTab != tab else { return }
        if newTab == .yaml {
            // Carry unsaved form edits over to the text.
            if formDirty { yamlText = EditorModel.yaml(from: items) }
        } else if yamlDirty {
            do {
                let selectedIndex = selection.flatMap { id in items.firstIndex(where: { $0.id == id }) }
                items = EditorModel.items(from: try ConfigParser.parse(yamlText))
                if let selectedIndex, items.indices.contains(selectedIndex) {
                    selection = items[selectedIndex].id
                } else {
                    selection = items.first?.id
                }
            } catch {
                show("Fix the YAML before switching: \(error.localizedDescription)", isError: true)
                return
            }
        }
        message = nil
        tab = newTab
    }

    /// Returns true if the config was written.
    @discardableResult
    private func save() -> Bool {
        if tab == .servers && !confirmDroppingComments() { return false }
        let text = tab == .servers ? EditorModel.yaml(from: items) : yamlText
        if let error = store.save(text) {
            show(error, isError: true)
            return false
        }
        loadFromStore()
        show("Saved", isError: false)
        return true
    }

    private static let skipCommentWarningKey = "SkipCommentWarning"

    /// The form tab rewrites the YAML from scratch, so hand-written comments are lost.
    private func confirmDroppingComments() -> Bool {
        let hasComments = store.rawText.split(separator: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("#") && trimmed != "# Lanyard config"
        }
        guard hasComments, !UserDefaults.standard.bool(forKey: Self.skipCommentWarningKey) else { return true }

        let alert = NSAlert()
        alert.messageText = "Saving here removes the comments in your config"
        alert.informativeText = "The Servers tab rewrites servers.yaml from the form. To keep your comments, make this change in the YAML tab instead."
        alert.addButton(withTitle: "Save Anyway")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        let confirmed = alert.runModal() == .alertFirstButtonReturn
        if confirmed && alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: Self.skipCommentWarningKey)
        }
        return confirmed
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

// MARK: - Server & service forms

struct ServerEditor: View {
    @Binding var item: EditorItem

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    SymbolWell(selection: $item.icon, defaultSymbol: "server.rack")
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            Text("Name")
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            TextField("Name", text: $item.name, prompt: Text("NAS"))
                        }
                        GridRow {
                            Text("Host")
                                .foregroundStyle(.secondary)
                            TextField("Host", text: $item.host, prompt: Text("nas.local"))
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }

            Section("Services") {
                ForEach(item.services) { service in
                    ServiceEditor(service: binding(for: service)) {
                        item.services.removeAll { $0.id == service.id }
                    }
                }
                Menu("Add Service") {
                    ForEach(ServiceKind.allCases, id: \.self) { kind in
                        Button(kind.displayName) {
                            item.services.append(EditorService(kind: kind))
                        }
                    }
                }
                .fixedSize()
            }
        }
        .formStyle(.grouped)
    }

    // Looked up by id, not array index: index-based bindings crash when a row
    // outlives its service (deleted, or the list reloaded from disk).
    private func binding(for service: EditorService) -> Binding<EditorService> {
        Binding(
            get: { item.services.first(where: { $0.id == service.id }) ?? service },
            set: { newValue in
                if let index = item.services.firstIndex(where: { $0.id == service.id }) {
                    item.services[index] = newValue
                }
            }
        )
    }
}

struct ServiceEditor: View {
    @Binding var service: EditorService
    var onDelete: () -> Void
    @State private var showOptions: Bool

    init(service: Binding<EditorService>, startExpanded: Bool = false, onDelete: @escaping () -> Void) {
        _service = service
        _showOptions = State(initialValue: startExpanded)
        self.onDelete = onDelete
    }

    private var usesPath: Bool { [ServiceKind.web, .smb, .nfs, .sftp].contains(service.kind) }
    private var usesUser: Bool { [ServiceKind.smb, .vnc, .ssh, .sftp, .rdp].contains(service.kind) }

    private var httpsBinding: Binding<Bool> {
        Binding(
            get: { service.https ?? ServiceKind.impliesHTTPS(port: Int(service.port)) },
            set: { newValue in
                service.https = newValue == ServiceKind.impliesHTTPS(port: Int(service.port)) ? nil : newValue
            }
        )
    }

    /// What the collapsed row shows, so services of the same type can be told apart.
    private var summary: String {
        if service.kind == .custom { return service.url }
        var parts: [String] = []
        let trimmed = { (s: String) in s.trimmingCharacters(in: .whitespaces) }
        if !trimmed(service.label).isEmpty { parts.append(trimmed(service.label)) }
        if !trimmed(service.user).isEmpty { parts.append(trimmed(service.user)) }
        if !trimmed(service.port).isEmpty { parts.append(":" + trimmed(service.port)) }
        if usesPath, !trimmed(service.path).isEmpty { parts.append(trimmed(service.path)) }
        if service.kind == .web, let https = service.https { parts.append(https ? "HTTPS" : "HTTP") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showOptions ? 90 : 0))
                    .frame(width: 12, height: 20)
                    .accessibilityHidden(true)
                Picker("Type", selection: $service.kind) {
                    ForEach(ServiceKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Text(summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove service")
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { showOptions.toggle() } }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(showOptions ? "Hides options" : "Shows options")

            if showOptions {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    if service.kind == .custom {
                        optionRow("URL") {
                            TextField("URL", text: $service.url, prompt: Text("https://{host}:9443"))
                        }
                    } else {
                        optionRow("Port") {
                            TextField("Port", text: $service.port,
                                      prompt: Text(service.kind.defaultPort.map(String.init) ?? ""))
                                .frame(width: 90)
                        }
                        if usesPath {
                            optionRow("Path") {
                                TextField("Path", text: $service.path, prompt: Text("Optional"))
                            }
                        }
                        if usesUser {
                            optionRow("User") {
                                TextField("User", text: $service.user, prompt: Text("Optional"))
                            }
                        }
                    }
                    optionRow("Label") {
                        TextField("Label", text: $service.label, prompt: Text(service.kind.displayName))
                    }
                    optionRow("Icon") {
                        SymbolPicker(selection: $service.icon, defaultSymbol: service.kind.defaultSymbol)
                    }
                    if service.kind == .web {
                        optionRow("HTTPS") {
                            Toggle("Use HTTPS", isOn: httpsBinding)
                                .toggleStyle(.checkbox)
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }

    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            content()
        }
    }
}

struct DividerEditor: View {
    @Binding var item: EditorItem

    var body: some View {
        Form {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 8) {
                    GridRow {
                        Text("Title")
                            .foregroundStyle(.secondary)
                        TextField("Title", text: $item.name, prompt: Text("Optional, e.g. Remote"))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                    }
                }
            } footer: {
                Text("Leave the title empty for a plain line.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Plain-text editor (no smart quotes, which would break YAML)

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = text
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        init(_ parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
