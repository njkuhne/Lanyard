import SwiftUI

struct SymbolPicker: View {
    @Binding var selection: String
    @State private var isPresented = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isPresented.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selection.isEmpty ? "square.dashed" : selection)
                        .frame(width: 18)
                    Text(selection.isEmpty ? "Choose…" : selection)
                        .lineLimit(1)
                        .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                }
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $isPresented) {
                SymbolGrid(selection: $selection, isPresented: $isPresented)
            }

            if !selection.isEmpty {
                Button {
                    selection = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear icon")
            }
        }
    }
}

private struct SymbolGrid: View {
    @Binding var selection: String
    @Binding var isPresented: Bool
    @State private var search = ""

    private var filtered: [(String, [String])] {
        if search.isEmpty { return SymbolCatalog.categories }
        let query = search.lowercased()
        let results = SymbolCatalog.categories.compactMap { (name, symbols) -> (String, [String])? in
            let matched = symbols.filter { $0.lowercased().contains(query) }
            return matched.isEmpty ? nil : (name, matched)
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search symbols…", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(filtered, id: \.0) { category, symbols in
                        Section {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 6) {
                                ForEach(symbols, id: \.self) { symbol in
                                    Button {
                                        selection = symbol
                                        isPresented = false
                                    } label: {
                                        Image(systemName: symbol)
                                            .font(.title2)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(selection == symbol ? Color.accentColor.opacity(0.2) : Color.clear)
                                            )
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
        .frame(width: 300, height: 400)
    }
}

enum SymbolCatalog {
    static let categories: [(String, [String])] = [
        ("Servers & Hardware", [
            "server.rack",
            "cpu",
            "memorychip",
            "desktopcomputer",
            "pc",
            "laptopcomputer",
            "macmini",
            "macpro.gen3",
            "display",
            "display.2",
            "printer",
            "scanner",
        ]),
        ("Network", [
            "network",
            "globe",
            "wifi",
            "antenna.radiowaves.left.and.right",
            "cable.connector",
            "link",
            "bolt.horizontal",
            "point.3.connected.trianglepath.dotted",
            "arrow.triangle.branch",
        ]),
        ("Storage", [
            "externaldrive",
            "externaldrive.fill",
            "internaldrive",
            "internaldrive.fill",
            "opticaldiscdrive",
            "folder",
            "folder.fill",
            "doc",
            "archivebox",
            "archivebox.fill",
            "cylinder",
            "cylinder.fill",
            "tray.2",
            "tray.full",
            "sdcard",
            "usbdrive",
        ]),
        ("Connectivity", [
            "cloud",
            "cloud.fill",
            "icloud",
            "arrow.up.arrow.down",
            "arrow.up.arrow.down.circle",
            "arrowshape.turn.up.right",
            "paperplane",
            "antenna.radiowaves.left.and.right.slash",
            "wifi.slash",
        ]),
        ("Security", [
            "lock",
            "lock.fill",
            "lock.shield",
            "key",
            "key.fill",
            "shield",
            "shield.fill",
            "shield.checkered",
            "person.badge.key",
        ]),
        ("Tools", [
            "terminal",
            "terminal.fill",
            "wrench",
            "wrench.and.screwdriver",
            "gearshape",
            "gearshape.2",
            "hammer",
            "gauge",
            "stethoscope",
            "waveform.path.ecg",
        ]),
        ("Apps & Media", [
            "play",
            "play.fill",
            "video",
            "video.fill",
            "camera",
            "photo",
            "music.note",
            "headphones",
            "speaker.wave.3",
            "tv",
            "gamecontroller",
        ]),
        ("Home & IoT", [
            "homekit",
            "house",
            "house.fill",
            "lightbulb",
            "lightbulb.fill",
            "fanblades",
            "thermometer.medium",
            "bolt",
            "bolt.fill",
            "powerplug",
            "ev.charger",
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
        ]),
        ("General", [
            "star",
            "star.fill",
            "heart",
            "heart.fill",
            "flag",
            "flag.fill",
            "bell",
            "bell.fill",
            "bookmark",
            "tag",
            "pin",
            "mappin",
            "chart.bar",
            "chart.line.uptrend.xyaxis",
            "clock",
            "calendar",
            "eye",
            "hand.raised",
            "person",
            "person.2",
        ]),
    ]
}
