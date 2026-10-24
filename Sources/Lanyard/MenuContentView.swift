import AppKit
import SwiftUI

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
                ForEach(store.config.entries) { entry in
                    switch entry {
                    case .server(let server):
                        ServerRow(server: server)
                    case .divider(_, let title):
                        DividerRow(title: title)
                    }
                }
            }

            Divider().padding(.top, 6)
            FooterView()
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(width: 320)
    }
}

struct ServerRow: View {
    let server: Server

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: SymbolCatalog.resolved(server.icon, fallback: "server.rack"))
                .foregroundStyle(.secondary)
                .frame(width: 18)

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

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                ForEach(server.services) { service in
                    ServiceButton(service: service, server: server)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(server.services) { service in
                Button("Open \(service.title)") { Launcher.open(service, on: server) }
            }
            if !server.services.isEmpty { Divider() }
            Button("Copy Host") { Launcher.copy(server.host) }
            Menu("Copy Address") {
                ForEach(server.services) { service in
                    if let url = service.url(for: server) {
                        Button(service.title) { Launcher.copy(url.absoluteString) }
                    }
                }
            }
            .disabled(server.services.isEmpty)
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
            Group {
                if let letter = service.badgeLetter {
                    LetterBadge(letter: letter)
                } else {
                    Image(systemName: service.symbol)
                        .symbolRenderingMode(.monochrome)
                        .symbolVariant(.none)
                        .font(.system(size: 13))
                }
            }
            .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovering ? Color.accentColor.opacity(0.22) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(service.title): \(service.url(for: server)?.absoluteString ?? "invalid address")")
        .onHover { hovering = $0 }
    }
}

struct LetterBadge: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .frame(width: 16, height: 16)
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
            Text(Self.formatted(message))
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.12)))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    /// Error messages use `backticks` for config keys; render them as code.
    static func formatted(_ message: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: message, options: options)) ?? AttributedString(message)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No servers yet")
                .font(.headline)
            Button("Add a Server…") {
                Launcher.closeMenu()
                EditorWindowController.shared.show(store: store)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct FooterView: View {
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        HStack {
            Button("Edit Servers…") {
                Launcher.closeMenu()
                EditorWindowController.shared.show(store: store)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Menu {
                Button("About Lanyard") {
                    Launcher.closeMenu()
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
                Divider()
                Menu("Config File") {
                    Button("Open in External Editor") {
                        Launcher.closeMenu()
                        store.openInEditor()
                    }
                    Button("Show in Finder") {
                        Launcher.closeMenu()
                        store.revealInFinder()
                    }
                    Button("Copy to Clipboard") { store.copyToClipboard() }
                    Divider()
                    Button("Reload") { store.reload() }
                }
                Divider()
                Toggle("Launch at Login", isOn: Binding(
                    get: { LoginItem.isEnabled },
                    set: { LoginItem.setEnabled($0) }
                ))
                Divider()
                Button("Quit Lanyard") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }
}

enum Launcher {
    static func open(_ service: Service, on server: Server) {
        guard let url = service.url(for: server) else {
            NSSound.beep()
            return
        }
        closeMenu()
        if !NSWorkspace.shared.open(url) {
            NSSound.beep()
        }
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func closeMenu() {
        NSApp.keyWindow?.close()
    }
}
