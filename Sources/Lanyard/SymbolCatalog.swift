import AppKit

enum SymbolCatalog {
    /// The name if this Mac has that symbol, otherwise the fallback, so a typo
    /// or a symbol from a newer macOS never shows up as a blank space.
    static func resolved(_ name: String?, fallback: String) -> String {
        guard let name, !name.isEmpty, isAvailable(name) else { return fallback }
        return name
    }

    /// The picker's sections: the default first, then each category. A search
    /// keeps whole categories whose name matches and otherwise matching symbols.
    static func sections(matching search: String, defaultSymbol: String) -> [(String, [String])] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return [("Default", [defaultSymbol])] + categories }
        return categories.compactMap { name, symbols in
            if name.lowercased().contains(query) { return (name, symbols) }
            let matched = symbols.filter { $0.lowercased().contains(query) }
            return matched.isEmpty ? nil : (name, matched)
        }
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
        ("Network", [
            "network",
            "wifi.router",
            "wifi",
            "antenna.radiowaves.left.and.right",
            "dot.radiowaves.left.and.right",
            "personalhotspot",
            "point.3.connected.trianglepath.dotted",
            "point.topleft.down.to.point.bottomright.curvepath",
            "arrow.triangle.branch",
            "arrow.triangle.swap",
            "arrow.left.arrow.right",
            "arrow.up.arrow.down",
            "cable.connector",
            "cable.coaxial",
            "rectangle.connected.to.line.below",
            "network.badge.shield.half.filled",
            "globe",
            "link",
            "bolt.horizontal",
            "airport.express",
            "airport.extreme",
            "airport.extreme.tower",
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
