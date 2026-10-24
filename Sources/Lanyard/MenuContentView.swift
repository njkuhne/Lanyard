import AppKit
import SwiftUI

/// Per-Mac display preferences for the dropdown, kept in UserDefaults rather than the YAML.
enum DisplayOption {
    static let showAddresses = "showAddresses"
    static let showServerIcons = "showServerIcons"
    static let compactRows = "compactRows"
}

struct MenuContentView: View {
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = store.errorMessage {
                ErrorBanner(message: message)
            }

            if store.config.entries.isEmpty {
                EmptyStateView()
            } else {
                ForEach(Array(store.config.entries.enumerated()), id: \.element.id) { index, entry in
                    switch entry {
                    case .server(let server):
                        ServerRow(server: server, index: index)
                    case .divider(_, let title):
                        DividerRow(title: title)
                    }
                }
            }

            Divider().padding(.top, 6)
            FooterView()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(width: 320)
    }
}

struct ServerRow: View {
    @EnvironmentObject var store: ConfigStore
    @AppStorage(DisplayOption.showAddresses) private var showAddresses = true
    @AppStorage(DisplayOption.showServerIcons) private var showServerIcons = true
    @AppStorage(DisplayOption.compactRows) private var compactRows = false

    let server: Server
    let index: Int

    private var singleLine: Bool { compactRows || !showAddresses }

    var body: some View {
        HStack(spacing: 8) {
            if showServerIcons {
                Image(systemName: SymbolCatalog.resolved(server.icon, fallback: "server.rack"))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            nameAndAddress
                .frame(minWidth: 100, alignment: .leading)
                .help("\(server.name) — \(server.host)")

            Spacer(minLength: 8)

            ServiceStripView(server: server)
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, singleLine ? 3 : 5)
        .frame(minHeight: singleLine ? 26 : nil)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(server.services) { service in
                Button("Open \(service.title)") { Launcher.open(service, on: server) }
            }
            if !server.services.isEmpty { Divider() }
            Button("Copy Address") { Launcher.copy(server.host) }
            Menu("Copy Service Link") {
                ForEach(server.services) { service in
                    if let url = service.url(for: server) {
                        Button(service.title) { Launcher.copy(url.absoluteString) }
                    }
                }
            }
            .disabled(server.services.isEmpty)
            Divider()
            Button("Edit “\(server.name)”…") {
                Launcher.closeMenu()
                EditorWindowController.servers.show(store: store, selectedIndex: index)
            }
        }
    }

    @ViewBuilder
    private var nameAndAddress: some View {
        if singleLine {
            HStack(spacing: 6) {
                Text(server.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .layoutPriority(1)
                if showAddresses {
                    Text(server.host)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(server.host)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

/// The row's service buttons: all of them up to five, otherwise four and a "+N" menu.
struct ServiceStripView: View {
    let server: Server

    var body: some View {
        let split = ServiceStrip.split(server.services.count)
        HStack(spacing: 2) {
            ForEach(server.services.prefix(split.visible)) { service in
                ServiceButton(service: service, server: server)
            }
            if split.hidden > 0 {
                Menu {
                    ForEach(server.services) { service in
                        Button {
                            Launcher.open(service, on: server)
                        } label: {
                            Text(service.title)
                            Text(service.url(for: server)?.absoluteString ?? server.host)
                        }
                    }
                } label: {
                    Text("+\(split.hidden)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 26, height: 24)
                .help("\(split.hidden) more")
            }
        }
    }
}

struct ServiceButton: View {
    let service: Service
    let server: Server
    @State private var hovering = false

    var body: some View {
        Button {
            Launcher.open(service, on: server)
        } label: {
            ServiceGlyph(service: service)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovering ? Color.accentColor.opacity(0.22) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(service.title): \(service.url(for: server)?.absoluteString ?? server.host)")
        .onHover { hovering = $0 }
    }
}

/// A service's badge if it has one, otherwise its icon.
struct ServiceGlyph: View {
    let service: Service

    var body: some View {
        if let badge = service.badgeText {
            LetterBadge(text: badge)
        } else {
            Image(systemName: service.symbol)
                .symbolRenderingMode(.monochrome)
                .symbolVariant(.none)
                .font(.system(size: 13))
        }
    }
}

struct LetterBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: text.count >= 3 ? 8 : 9.5, weight: .bold, design: .rounded))
            .lineLimit(1)
            .frame(width: CGFloat(12 + 4 * max(text.count, 1)), height: 16)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 1.2))
    }
}

struct DividerRow: View {
    let title: String?

    var body: some View {
        if let title {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.top, 10)
                .padding(.bottom, 2)
        } else {
            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(ConfigError.formatted(message))
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.12)))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "server.rack")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("No servers yet")
                .font(.headline)
            Text("Open web UIs, shares and Screen Sharing in one click.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Server…") {
                Launcher.closeMenu()
                EditorWindowController.addServer.show(store: store)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

struct FooterView: View {
    @EnvironmentObject var store: ConfigStore
    @AppStorage(DisplayOption.showAddresses) private var showAddresses = true
    @AppStorage(DisplayOption.showServerIcons) private var showServerIcons = true
    @AppStorage(DisplayOption.compactRows) private var compactRows = false

    var body: some View {
        HStack {
            Button {
                Launcher.closeMenu()
                EditorWindowController.addServer.show(store: store)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Add Server…")

            Spacer()

            Menu {
                Button("Edit Servers…") {
                    Launcher.closeMenu()
                    EditorWindowController.servers.show(store: store)
                }
                .keyboardShortcut(",", modifiers: .command)
                Button("Edit YAML…") {
                    Launcher.closeMenu()
                    EditorWindowController.yaml.show(store: store)
                }
                Divider()
                Menu("Display") {
                    Toggle("Show Addresses", isOn: $showAddresses)
                    Toggle("Show Server Icons", isOn: $showServerIcons)
                    Toggle("Compact Rows", isOn: $compactRows)
                }
                Menu("Config File") {
                    Button("Open in External Editor") {
                        Launcher.closeMenu()
                        store.openInEditor()
                    }
                    Button("Show in Finder") {
                        Launcher.closeMenu()
                        store.revealInFinder()
                    }
                    Divider()
                    Button("Reload") { store.reload() }
                }
                Toggle("Launch at Login", isOn: Binding(
                    get: { LoginItem.isEnabled },
                    set: { LoginItem.setEnabled($0) }
                ))
                Divider()
                Button("About Lanyard") {
                    Launcher.closeMenu()
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
                Button("Quit Lanyard") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings")
        }
        .frame(height: 30)
        .padding(.horizontal, 14)
    }
}
