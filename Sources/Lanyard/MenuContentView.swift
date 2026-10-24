import AppKit
import SwiftUI

/// Lanyard's greyscale accent, used instead of the system's blue.
enum Theme {
    static let accent = Color(nsColor: NSColor(name: "LanyardAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.62, alpha: 1)
            : NSColor(white: 0.24, alpha: 1)
    })
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
        .tint(Theme.accent)
    }
}

struct ServerRow: View {
    @EnvironmentObject var store: ConfigStore

    let server: Server
    let index: Int

    private var showAddresses: Bool { server.showAddress }
    private var showServerIcons: Bool { server.showIcon }
    private var singleLine: Bool { !server.showAddress }

    var body: some View {
        // Everything on one line when it fits; otherwise the name gets its own
        // line(s) and every service button wraps below it, so none are hidden.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                serverIcon
                nameAndAddress(wrapping: false)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                HStack(spacing: 2) { serviceButtons }
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    serverIcon
                    nameAndAddress(wrapping: true)
                    Spacer(minLength: 0)
                }
                if !server.services.isEmpty {
                    FlowLayout(spacing: 2) { serviceButtons }
                        .padding(.leading, showServerIcons ? 22 : -4)
                }
            }
        }
        .help("\(server.name) — \(server.host)")
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
    private var serverIcon: some View {
        if showServerIcons {
            Image(systemName: SymbolCatalog.resolved(server.icon, fallback: "server.rack"))
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
    }

    private var serviceButtons: some View {
        ForEach(server.services) { service in
            ServiceButton(service: service, server: server)
        }
    }

    @ViewBuilder
    private func nameAndAddress(wrapping: Bool) -> some View {
        if singleLine && !wrapping {
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
                    .lineLimit(wrapping ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: wrapping)
                if showAddresses {
                    Text(server.host)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
            }
        }
    }
}

/// Lays out service buttons left to right, wrapping onto as many lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes: [CGSize] = subviews.map { $0.sizeThatFits(.unspecified) }
        let widths: [CGFloat] = sizes.map { $0.width }
        let rows = FlowRows.rows(widths: widths, maxWidth: proposal.width ?? .infinity, spacing: spacing)
        var width: CGFloat = 0
        var height: CGFloat = 0
        for row in rows {
            var rowWidth: CGFloat = 0
            var rowHeight: CGFloat = 0
            for index in row {
                rowWidth += sizes[index].width
                rowHeight = max(rowHeight, sizes[index].height)
            }
            rowWidth += spacing * CGFloat(row.count - 1)
            width = max(width, rowWidth)
            height += rowHeight
        }
        height += spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var y = bounds.minY
        let widths: [CGFloat] = sizes.map { $0.width }
        for row in FlowRows.rows(widths: widths, maxWidth: bounds.width, spacing: spacing) {
            var x = bounds.minX
            var rowHeight: CGFloat = 0
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sizes[index]))
                x += sizes[index].width + spacing
                rowHeight = max(rowHeight, sizes[index].height)
            }
            y += rowHeight + spacing
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
                        .fill(hovering ? Theme.accent.opacity(0.22) : Color.clear)
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
        if let badge = service.badge {
            LetterBadge(text: badge)
        } else if service.kind == .app, service.icon == nil, let bundle = service.bundle {
            AppIcon(bundle: bundle, size: 16)
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
        // Sizes chosen by measuring rendered margins: at 10pt (1–2 letters) and 8.5pt
        // (3 letters) capitals land centred with no offset. Whole-point frame and
        // outline keep every edge on a pixel, so it stays sharp at 1x.
        Text(text)
            .font(.system(size: text.count >= 3 ? 8.5 : 10, weight: .bold, design: .rounded))
            .lineLimit(1)
            .frame(width: CGFloat(12 + 4 * max(text.count, 1)), height: 16)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 1))
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
    @AppStorage(AppearanceMode.defaultsKey) private var appearance = AppearanceMode.system.rawValue

    var body: some View {
        HStack {
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
                Picker("Appearance", selection: Binding(
                    get: { AppearanceMode(stored: appearance) },
                    set: { mode in
                        appearance = mode.rawValue
                        mode.apply()
                    }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
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
