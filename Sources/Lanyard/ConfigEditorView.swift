import AppKit
import SwiftUI

struct ConfigEditorView: View {
    @ObservedObject private var store: ConfigStore
    @StateObject private var state: EditorState
    private let session: EditorSession?

    init(
        store: ConfigStore,
        selectedIndex: Int? = nil,
        session: EditorSession? = nil,
        prompts: EditorPrompts = .system
    ) {
        self.store = store
        _state = StateObject(wrappedValue: EditorState(store: store, selectedIndex: selectedIndex, prompts: prompts))
        self.session = session
    }

    var body: some View {
        VStack(spacing: 0) {
            serversList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            EditorBottomBar(
                message: state.message,
                messageIsError: state.messageIsError,
                hasUnsavedChanges: state.hasUnsavedChanges,
                revert: state.revert,
                save: { state.save() }
            )
        }
        .frame(minWidth: 720, minHeight: 480)
        .tint(Theme.accent)
        .onAppear {
            session?.save = { [state] in state.save() }
            session?.select = { [state] in state.select(index: $0) }
        }
        .onChange(of: state.hasUnsavedChanges) { session?.isDirty = $0 }
        .onChange(of: store.rawText) { _ in state.storeDidChange() }
    }

    private var serversList: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $state.selection) {
                    ForEach(state.items) { item in
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
                    .onMove(perform: state.move)
                    .onDelete(perform: state.remove)
                }
                .onDeleteCommand(perform: state.deleteSelected)

                Divider()

                HStack(spacing: 6) {
                    Menu {
                        Button("Add Server", action: state.addServer)
                        Button("Add Divider", action: state.addDivider)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()

                    Button(action: state.deleteSelected) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(state.selection == nil)

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
        if let id = state.selection, let item = state.item(with: id) {
            Group {
                if item.isDivider {
                    DividerEditor(item: binding(for: item))
                } else {
                    ServerEditor(item: binding(for: item))
                }
            }
            .id(id)
        } else if state.items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No servers yet")
                    .font(.title3)
                Text("Add one here, or paste a whole config with Edit YAML… in the menu.")
                    .foregroundStyle(.secondary)
                Button("Add Server", action: state.addServer)
                    .padding(.top, 6)
            }
        } else {
            Text("Select a server")
                .foregroundStyle(.secondary)
        }
    }

    private func binding(for item: EditorItem) -> Binding<EditorItem> {
        Binding(get: { state.item(with: item.id) ?? item }, set: state.update)
    }

}

/// Revert/Save bar shared by both editor windows.
struct EditorBottomBar: View {
    let message: String?
    let messageIsError: Bool
    let hasUnsavedChanges: Bool
    let revert: () -> Void
    let save: () -> Void

    var body: some View {
        HStack {
            if let message {
                Label(message, systemImage: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(messageIsError ? Color.orange : Color.green)
                    .font(.callout)
                    .lineLimit(3)
            }
            Spacer()
            Button("Revert", action: revert)
                .disabled(!hasUnsavedChanges)
            Button("Save", action: save)
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!hasUnsavedChanges)
        }
        .padding(12)
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
                            Text("Address")
                                .foregroundStyle(.secondary)
                            TextField("Address", text: $item.host, prompt: Text("nas.local or 192.168.1.10"))
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                }
                .padding(.vertical, 4)

                HStack(spacing: 16) {
                    Text("In the menu")
                        .foregroundStyle(.secondary)
                    Toggle("Show address", isOn: $item.showAddress)
                    Toggle("Show icon", isOn: $item.showIcon)
                }
                .toggleStyle(.checkbox)
            }

            Section {
                if item.services.isEmpty {
                    Text("No services yet. Add one below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(item.services) { service in
                    ServiceEditor(service: binding(for: service), serverAddress: item.host, badgeClash: item.badgeClash(for: service)?.title) {
                        item.services.removeAll { $0.id == service.id }
                    }
                }
            } header: {
                Text("Services")
            }

            Section("Add a Service") {
                HStack(spacing: 6) {
                    ForEach(ServiceKind.allCases, id: \.self) { kind in
                        AddServiceTile(kind: kind) {
                            item.services.append(EditorService(kind: kind))
                        }
                    }
                }
                .padding(.vertical, 2)
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

struct AddServiceTile: View {
    let kind: ServiceKind
    var isSelected = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: kind.defaultSymbol)
                    .symbolRenderingMode(.monochrome)
                    .symbolVariant(.none)
                    .font(.system(size: 16))
                    .frame(height: 20)
                Text(kind.tileName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.accent.opacity(0.18) : Color.primary.opacity(hovering ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(kind.displayName)
        .accessibilityLabel(kind.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ServiceEditor: View {
    @Binding var service: EditorService
    var badgeClash: String?
    var serverAddress = ""
    var onDelete: () -> Void
    @State private var showOptions: Bool
    @State private var useBadge: Bool

    init(
        service: Binding<EditorService>,
        serverAddress: String = "",
        badgeClash: String? = nil,
        startExpanded: Bool = false,
        onDelete: @escaping () -> Void
    ) {
        _service = service
        self.serverAddress = serverAddress
        self.badgeClash = badgeClash
        // A new app service starts open so its app can be chosen.
        _showOptions = State(initialValue: startExpanded || (service.wrappedValue.kind == .app && service.wrappedValue.bundle.isEmpty))
        _useBadge = State(initialValue: service.wrappedValue.showsBadge)
        self.onDelete = onDelete
    }


    /// Empty means the server's own address, so show what that would open.
    private var addressPrompt: String {
        let host = serverAddress.trimmingCharacters(in: .whitespaces)
        guard let scheme = service.kind.scheme, !host.isEmpty else { return service.kind.example }
        return "\(scheme)://\(host)  (e.g. \(service.kind.example))"
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
                Group {
                    if service.showsBadge {
                        LetterBadge(text: service.badge)
                    } else if service.kind == .app && service.icon.isEmpty {
                        AppIcon(bundle: service.bundle, size: 16)
                    } else {
                        Image(systemName: SymbolCatalog.resolved(service.icon, fallback: service.kind.defaultSymbol))
                            .symbolRenderingMode(.monochrome)
                            .symbolVariant(.none)
                    }
                }
                .frame(minWidth: 18)
                Text(service.kind.displayName)
                    .fixedSize()
                Text(service.summary)
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
                    if service.kind == .app {
                        optionRow("App") {
                            HStack(spacing: 8) {
                                AppIcon(bundle: service.bundle, size: 18)
                                Text(service.bundle.isEmpty ? "None chosen" : AppInfo.name(for: service.bundle))
                                    .foregroundStyle(service.bundle.isEmpty ? .secondary : .primary)
                                Button("Choose…") {
                                    if let bundle = AppInfo.choose() { service.bundle = bundle }
                                }
                            }
                        }
                        optionRow("Open URL") {
                            TextField("Open URL", text: $service.url,
                                      prompt: Text("Optional, handed to the app, e.g. myapp://{address}"))
                        }
                    } else {
                        optionRow("Address") {
                            TextField("Address", text: $service.url, prompt: Text(addressPrompt))
                        }
                    }
                    optionRow("Name") {
                        TextField("Name", text: $service.label, prompt: Text(service.kind.displayName))
                    }
                    optionRow("Show") {
                        Picker("Show", selection: $useBadge) {
                            Text("Icon").tag(false)
                            Text("Badge").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .onChange(of: useBadge) { service.showsBadge = $0 }
                    }
                    if useBadge {
                        optionRow("Badge") {
                            HStack(spacing: 8) {
                                TextField("Badge", text: $service.badgeInput, prompt: Text("1–3 letters"))
                                    .frame(width: 90)
                                if !service.badge.isEmpty {
                                    LetterBadge(text: service.badge)
                                }
                                if let badgeClash {
                                    Label("Same badge as \(badgeClash)", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    } else {
                        optionRow("Icon") {
                            SymbolPicker(selection: $service.icon, defaultSymbol: service.kind.defaultSymbol)
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

/// The Add Server window, which is also the first-run experience.
struct AddServerView: View {
    @StateObject private var state: AddServerState
    private let close: () -> Void
    private let pasteYAML: () -> Void

    init(store: ConfigStore, close: @escaping () -> Void = {}, pasteYAML: @escaping () -> Void = {}) {
        _state = StateObject(wrappedValue: AddServerState(store: store))
        self.close = close
        self.pasteYAML = pasteYAML
    }

    var body: some View {
        Group {
            if let added = state.added {
                done(added)
            } else {
                form
            }
        }
        .frame(width: 440)
        .tint(Theme.accent)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.isFirstServer ? "Add your first server" : "Add a server")
                    .font(.title2.weight(.semibold))
                Text("Lanyard keeps your servers one click away in the menu bar.")
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("Address").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    TextField("Address", text: $state.address, prompt: Text("nas.local or 192.168.1.10"))
                }
                GridRow {
                    Text("Name").foregroundStyle(.secondary)
                    TextField("Name", text: $state.name, prompt: Text("Defaults to the address"))
                }
            }
            .textFieldStyle(.roundedBorder)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 8) {
                Text("What do you open on it?")
                    .font(.headline)
                HStack(spacing: 6) {
                    ForEach(ServiceKind.allCases.filter { $0 != .app }, id: \.self) { kind in
                        AddServiceTile(kind: kind, isSelected: state.kinds.contains(kind)) {
                            state.toggle(kind)
                        }
                    }
                }
            }

            if state.kinds.contains(.web) {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Text("Web address").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        TextField("Web address", text: $state.webAddress, prompt: Text(state.webPrompt))
                    }
                    GridRow {
                        Text("Web name").foregroundStyle(.secondary)
                        HStack {
                            TextField("Web name", text: $state.webName, prompt: Text("Optional"))
                            Text("Badge").foregroundStyle(.secondary)
                            TextField("Badge", text: $state.webBadge, prompt: Text("1–3"))
                                .frame(width: 50)
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
            }

            if let error = state.error {
                Label {
                    Text(ConfigError.formatted(error))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.orange)
                .font(.callout)
            }

            HStack {
                Button("Paste YAML…", action: pasteYAML)
                    .buttonStyle(.borderless)
                Spacer()
                Button("Add to Menu Bar") { state.add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canAdd)
            }
        }
        .padding(20)
    }

    private func done(_ name: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("Added \(name)")
                .font(.title3.weight(.semibold))
            Text("Find it in the menu bar ↑")
                .foregroundStyle(.secondary)
            HStack {
                Button("Add Another", action: state.addAnother)
                Button("Close", action: close)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

/// An app's own icon, or the generic app symbol when it isn't installed.
struct AppIcon: View {
    let bundle: String
    let size: CGFloat

    var body: some View {
        if let image = AppInfo.icon(for: bundle) {
            Image(nsImage: image)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app")
                .font(.system(size: size * 0.8))
                .frame(width: size, height: size)
        }
    }
}
