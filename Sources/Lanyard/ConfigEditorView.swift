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
        .onAppear { session?.save = { [state] in state.save() } }
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
            }

            Section("Services") {
                if item.services.isEmpty {
                    Text("No services yet. Add one below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(item.services) { service in
                    ServiceEditor(service: binding(for: service)) {
                        item.services.removeAll { $0.id == service.id }
                    }
                }
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
                    .fill(Color.primary.opacity(hovering ? 0.1 : 0.05))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add \(kind.displayName)")
        .accessibilityLabel("Add \(kind.displayName)")
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


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showOptions ? 90 : 0))
                    .frame(width: 12, height: 20)
                    .accessibilityHidden(true)
                Image(systemName: SymbolCatalog.resolved(service.icon, fallback: service.kind.defaultSymbol))
                    .symbolRenderingMode(.monochrome)
                    .symbolVariant(.none)
                    .frame(width: 18)
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
                    optionRow("Port") {
                        TextField("Port", text: $service.port,
                                  prompt: Text(service.kind.defaultPort.map(String.init) ?? ""))
                            .frame(width: 90)
                            .disabled(service.hasURL)
                    }
                    if service.kind.usesPath {
                        optionRow("Path") {
                            TextField("Path", text: $service.path, prompt: Text("Optional"))
                                .disabled(service.hasURL)
                        }
                    }
                    if service.kind == .web {
                        optionRow("Full URL") {
                            TextField("Full URL", text: $service.url,
                                      prompt: Text("Optional, replaces port and path, e.g. https://{address}:9443/admin"))
                        }
                    }
                    if service.kind.usesUser {
                        optionRow("User") {
                            TextField("User", text: $service.user, prompt: Text("Optional"))
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
                            Toggle("Use HTTPS", isOn: $service.usesHTTPS)
                                .toggleStyle(.checkbox)
                                .disabled(service.hasURL)
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
