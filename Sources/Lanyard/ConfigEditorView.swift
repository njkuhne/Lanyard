import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConfigEditorView: View {
    @EnvironmentObject var store: ConfigStore

    private enum Tab: Hashable { case servers, yaml }

    @State private var tab: Tab = .servers
    @State private var items: [EditorItem] = []
    @State private var savedItems: [EditorItem] = []
    @State private var selection: EditorItem.ID?
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
        .onAppear(perform: loadFromStore)
        .onChange(of: store.rawText) { _ in
            // Pick up outside edits, but never clobber unsaved work.
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
                            Image(systemName: item.isDivider ? "minus" : (item.icon.isEmpty ? "server.rack" : item.icon))
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            Text(item.listTitle)
                                .foregroundStyle(item.isDivider ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .tag(item.id)
                    }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { items.remove(atOffsets: $0) }
                }

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
                    Text("Drag to reorder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
            if item.isDivider {
                DividerEditor(item: binding(for: id))
            } else {
                ServerEditor(item: binding(for: id))
            }
        } else {
            Text(items.isEmpty ? "Add a server with +" : "Select a server")
                .foregroundStyle(.secondary)
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
                items = EditorModel.items(from: try ConfigParser.parse(yamlText))
                selection = items.first?.id
            } catch {
                show("Fix the YAML before switching: \(error.localizedDescription)", isError: true)
                return
            }
        }
        message = nil
        tab = newTab
    }

    private func save() {
        let text = tab == .servers ? EditorModel.yaml(from: items) : yamlText
        if let error = store.save(text) {
            show(error, isError: true)
        } else {
            loadFromStore()
            show("Saved", isError: false)
        }
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
                TextField("Name", text: $item.name, prompt: Text("NAS"))
                TextField("Host", text: $item.host, prompt: Text("nas.local"))
                TextField("User", text: $item.user, prompt: Text("Optional, used by SMB, VNC, SSH"))
                TextField("Icon", text: $item.icon, prompt: Text("Optional SF Symbol, e.g. externaldrive"))
            }

            Section("Services") {
                ForEach($item.services) { $service in
                    let id = service.id
                    ServiceEditor(service: $service) {
                        item.services.removeAll { $0.id == id }
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
}

struct ServiceEditor: View {
    @Binding var service: EditorService
    var onDelete: () -> Void

    private var usesPath: Bool { [ServiceKind.web, .smb, .nfs, .sftp].contains(service.kind) }
    private var usesUser: Bool { [ServiceKind.smb, .vnc, .ssh, .sftp].contains(service.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: service.icon.isEmpty ? service.kind.defaultSymbol : service.icon)
                    .frame(width: 18)
                Picker("Type", selection: $service.kind) {
                    ForEach(ServiceKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .fixedSize()
                if service.kind == .web {
                    Toggle("HTTPS", isOn: $service.https)
                        .toggleStyle(.checkbox)
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove service")
            }

            if service.kind == .custom {
                TextField("URL", text: $service.url, prompt: Text("URL, e.g. https://{host}:9443"))
                    .labelsHidden()
            } else {
                HStack {
                    TextField("Port", text: $service.port, prompt: Text("Port"))
                        .frame(width: 80)
                    if usesPath {
                        TextField("Path", text: $service.path, prompt: Text("Path"))
                    }
                    if usesUser {
                        TextField("User", text: $service.user, prompt: Text("User"))
                            .frame(width: 120)
                    }
                }
                .labelsHidden()
            }

            HStack {
                TextField("Label", text: $service.label, prompt: Text("Label (\(service.kind.displayName))"))
                TextField("Icon", text: $service.icon, prompt: Text("Icon (\(service.kind.defaultSymbol))"))
            }
            .labelsHidden()
        }
        .textFieldStyle(.roundedBorder)
        .padding(.vertical, 4)
    }
}

struct DividerEditor: View {
    @Binding var item: EditorItem

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $item.name, prompt: Text("Optional, e.g. Remote"))
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
