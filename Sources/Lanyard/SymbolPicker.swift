import AppKit
import SwiftUI

/// Large clickable icon square, used for a server's icon.
struct SymbolWell: View {
    @Binding var selection: String
    let defaultSymbol: String
    @State private var isPresented = false
    @State private var hovering = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: SymbolCatalog.resolved(selection, fallback: defaultSymbol))
                .font(.system(size: 28))
                .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(hovering ? 0.09 : 0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isPresented ? Color.accentColor : Color.primary.opacity(0.15),
                            style: StrokeStyle(lineWidth: isPresented ? 2 : 1, dash: selection.isEmpty ? [4, 3] : [])
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Click to choose an icon")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SymbolGrid(selection: $selection, defaultSymbol: defaultSymbol, isPresented: $isPresented)
        }
        .contextMenu {
            if !selection.isEmpty {
                Button("Use Default Icon") { selection = "" }
            }
        }
    }
}

/// Compact icon button for a service. Empty selection means "use the type's default".
struct SymbolPicker: View {
    @Binding var selection: String
    let defaultSymbol: String
    @State private var isPresented = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isPresented.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: SymbolCatalog.resolved(selection, fallback: defaultSymbol))
                        .frame(width: 18)
                    Text(selection.isEmpty ? "Default" : "Custom")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .help("Choose an icon")
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                SymbolGrid(selection: $selection, defaultSymbol: defaultSymbol, isPresented: $isPresented)
            }

            if !selection.isEmpty {
                Button {
                    selection = ""
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Use the default icon")
            }
        }
    }
}

private struct SymbolGrid: View {
    @Binding var selection: String
    let defaultSymbol: String
    @Binding var isPresented: Bool
    @State private var search = ""

    private var current: String { selection.isEmpty ? defaultSymbol : selection }

    private var sections: [(String, [String])] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return [("Default", [defaultSymbol])] + SymbolCatalog.categories }
        return SymbolCatalog.categories.compactMap { name, symbols in
            if name.lowercased().contains(query) { return (name, symbols) }
            let matched = symbols.filter { $0.lowercased().contains(query) }
            return matched.isEmpty ? nil : (name, matched)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search icons", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if sections.isEmpty {
                        Text("No icons match “\(search)”")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(sections, id: \.0) { category, symbols in
                        Section {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 6) {
                                ForEach(symbols, id: \.self) { symbol in
                                    Button {
                                        selection = symbol == defaultSymbol ? "" : symbol
                                        isPresented = false
                                    } label: {
                                        Image(systemName: symbol)
                                            .font(.title2)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(current == symbol ? Color.accentColor.opacity(0.22) : Color.clear)
                                            )
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help(symbol)
                                }
                            }
                        } header: {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(width: 340, height: 420)
    }
}

enum SymbolCatalog {
    /// The name if this Mac has that symbol, otherwise the fallback, so a typo
    /// or a symbol from a newer macOS never shows up as a blank space.
    static func resolved(_ name: String?, fallback: String) -> String {
        guard let name, !name.isEmpty, isAvailable(name) else { return fallback }
        return name
    }

    static func isAvailable(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    /// Only symbols that exist on the running macOS.
    static let categories: [(String, [String])] = catalog.compactMap { name, symbols in
        let available = symbols.filter(isAvailable)
        return available.isEmpty ? nil : (name, available)
    }

    // Apple-product symbols (macmini, appletv, airport…) may only stand for those products.
    private static let catalog: [(String, [String])] = [
        ("Network", [
            "network",
            "wifi.router",
            "wifi.router.fill",
            "wifi",
            "antenna.radiowaves.left.and.right",
            "dot.radiowaves.left.and.right",
            "dot.radiowaves.up.forward",
            "personalhotspot",
            "point.3.connected.trianglepath.dotted",
            "point.3.filled.connected.trianglepath.dotted",
            "point.topleft.down.to.point.bottomright.curvepath",
            "arrow.triangle.branch",
            "arrow.triangle.swap",
            "arrow.left.arrow.right",
            "arrow.up.arrow.down",
            "cable.connector",
            "cable.connector.horizontal",
            "cable.coaxial",
            "rectangle.connected.to.line.below",
            "network.badge.shield.half.filled",
            "globe",
            "globe.americas",
            "link",
            "bolt.horizontal",
            "airport.express",
            "airport.extreme",
            "airport.extreme.tower",
        ]),
        ("Servers & Hardware", [
            "server.rack",
            "xserve",
            "xserve.raid",
            "cpu",
            "memorychip",
            "fan",
            "desktopcomputer",
            "pc",
            "laptopcomputer",
            "macmini",
            "macstudio",
            "macpro.gen3",
            "display",
            "display.2",
            "printer",
            "scanner",
        ]),
        ("Storage", [
            "externaldrive",
            "externaldrive.fill",
            "externaldrive.connected.to.line.below",
            "externaldrive.badge.wifi",
            "externaldrive.badge.timemachine",
            "internaldrive",
            "internaldrive.fill",
            "opticaldiscdrive",
            "cylinder",
            "cylinder.fill",
            "cylinder.split.1x2",
            "folder",
            "folder.fill",
            "archivebox",
            "archivebox.fill",
            "tray.2",
            "tray.full",
            "sdcard",
            "photo.stack",
        ]),
        ("Security", [
            "lock.shield",
            "lock.shield.fill",
            "shield",
            "shield.fill",
            "shield.lefthalf.filled",
            "checkmark.shield",
            "shield.checkered",
            "lock",
            "lock.fill",
            "key",
            "key.fill",
            "person.badge.key",
            "web.camera",
            "video.doorbell",
            "eye",
        ]),
        ("Power", [
            "bolt",
            "bolt.fill",
            "bolt.batteryblock",
            "battery.100.bolt",
            "powerplug",
            "poweroutlet.type.b",
            "powercord",
            "ev.charger",
            "sun.max",
        ]),
        ("Home & IoT", [
            "homekit",
            "house",
            "house.fill",
            "lightbulb",
            "lightbulb.fill",
            "light.recessed",
            "sensor",
            "sensor.fill",
            "thermometer.medium",
            "humidity",
            "fanblades",
            "air.purifier",
            "hifispeaker",
            "tv",
            "appletv",
            "homepod",
        ]),
        ("Containers & Services", [
            "shippingbox",
            "shippingbox.fill",
            "cube",
            "cube.fill",
            "square.stack.3d.up",
            "square.stack.3d.down.right",
            "puzzlepiece",
            "app",
            "square.grid.2x2",
            "rectangle.3.group",
            "cloud",
            "cloud.fill",
            "icloud",
            "envelope",
            "bubble.left.and.bubble.right",
        ]),
        ("Tools", [
            "terminal",
            "terminal.fill",
            "chevron.left.forwardslash.chevron.right",
            "wrench",
            "wrench.and.screwdriver",
            "gearshape",
            "gearshape.2",
            "hammer",
            "gauge.with.dots.needle.33percent",
            "chart.bar",
            "chart.line.uptrend.xyaxis",
            "waveform.path.ecg",
            "stethoscope",
            "doc.text.magnifyingglass",
            "arrow.clockwise",
        ]),
        ("Media", [
            "play.rectangle",
            "play.fill",
            "film",
            "video",
            "camera",
            "photo",
            "music.note",
            "headphones",
            "books.vertical",
            "newspaper",
            "gamecontroller",
        ]),
        ("General", [
            "star",
            "star.fill",
            "heart",
            "flag",
            "bell",
            "bookmark",
            "tag",
            "pin",
            "mappin",
            "clock",
            "calendar",
            "person",
            "person.2",
            "building.2",
            "briefcase",
        ]),
    ]
}
