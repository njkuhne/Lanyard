import AppKit
import SwiftUI
import XCTest
@testable import Dotlocal

/// README screenshots: the real UI placed on a neutral desktop with a menu bar,
/// so readers see where dotlocal lives. Not a regression test; run with
/// `SCREENSHOTS=1 swift test --filter ScreenshotTests` to regenerate docs/screenshots.
@MainActor
final class ScreenshotTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] != nil, "Set SCREENSHOTS=1 to regenerate README screenshots")
        _ = NSApplication.shared
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("DotlocalShots-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func store(_ yaml: String = DemoConfig.text) -> ConfigStore {
        let url = directory.appendingPathComponent("servers.yaml")
        try? yaml.write(to: url, atomically: true, encoding: .utf8)
        return ConfigStore(fileURL: url)
    }

    private func save<V: View>(_ view: V, _ name: String, dark: Bool, width: CGFloat = 1000, height: CGFloat = 640) throws {
        let png = try XCTUnwrap(render(view, width: width, height: height, appearance: dark ? .dark : .light))
        let docs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/screenshots")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try png.write(to: docs.appendingPathComponent("\(name).png"))
    }

    func testMenu() throws {
        for dark in [false, true] {
            let scene = Desktop(dark: dark) {
                MenuPanel {
                    MenuContentView().environmentObject(store())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 4)
                .padding(.trailing, 118)
            }
            try save(scene, dark ? "menu-dark" : "menu", dark: dark, width: 900, height: 380)
        }
    }

    /// A server with a long name and 15 services, next to an ordinary one.
    func testCrowdedMenu() throws {
        let apps = ["Portainer:PT", "Grafana:GF", "Prometheus:PR", "Home Assistant:HA", "Jellyfin:JF", "Sonarr:SN",
                    "Radarr:RD", "Prowlarr:PW", "qBittorrent:QB", "Nextcloud:NC", "Vaultwarden:VW", "Immich:IM",
                    "Paperless:PL", "Uptime Kuma:UK"]
        var yaml = "servers:\n  - name: Proxmox cluster node with a very long name\n    address: pve-node-01.homelab.internal\n    services:\n"
        for (i, entry) in apps.enumerated() {
            let parts = entry.split(separator: ":")
            yaml += "      - web: { url: \"http://pve-node-01.homelab.internal:\(8000 + i)\", name: \(parts[0]), badge: \(parts[1]) }\n"
        }
        yaml += "      - ssh\n  - name: NAS\n    address: nas.local\n    services:\n      - web: https://nas.local:5001\n      - smb\n"
        let scene = Desktop(dark: false) {
            MenuPanel {
                MenuContentView().environmentObject(store(yaml))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 4)
            .padding(.trailing, 118)
        }
        try save(scene, "menu-crowded", dark: false, width: 900, height: 420)
    }

    func testEditor() throws {
        let scene = Desktop(dark: false) {
            FakeWindow(title: "Edit Servers") {
                ConfigEditorView(store: store(), selectedIndex: 2)
                    .frame(width: 780, height: 650)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        try save(scene, "editor", dark: false, height: 790)
    }

    func testFirstRun() throws {
        let scene = Desktop(dark: false) {
            FakeWindow(title: "Add Server") {
                AddServerView(store: store(SampleConfig.starter))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        try save(scene, "first-run", dark: false, width: 900, height: 600)
    }

    /// Mac App Store screenshots: 1440×900 points rendered at 2x, so 2880×1800 pixels.
    func testAppStore() throws {
        func shot<V: View>(_ name: String, dark: Bool = false, caption: String, detail: String, @ViewBuilder _ content: () -> V) throws {
            let scene = Desktop(dark: dark) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(caption).font(.system(size: 44, weight: .bold))
                        Text(detail).font(.system(size: 22)).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(dark ? Color.white : Color.black)
                    .frame(width: 440, alignment: .leading)
                    .padding(.top, 120)
                    .padding(.leading, 90)
                    Spacer(minLength: 0)
                    content()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            let png = try XCTUnwrap(render(scene, width: 1440, height: 900, appearance: dark ? .dark : .light))
            let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("docs/appstore")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            try png.write(to: out.appendingPathComponent("\(name).png"))
        }
        func menu(_ yaml: String = DemoConfig.text) -> some View {
            MenuPanel { MenuContentView().environmentObject(store(yaml)) }
                .padding(.top, 4)
                .padding(.trailing, 150)
        }

        try shot("1-menu", caption: "Your homelab, one click away.",
                 detail: "Every server in your menu bar, with an icon for each service.") { menu() }
        try shot("2-dark", dark: true, caption: "Opens the right tool.",
                 detail: "Web UIs in your browser, shares in Finder, Screen Sharing, SSH in Terminal.") { menu() }
        try shot("3-editor", caption: "Point and click, or YAML.",
                 detail: "Edit servers in a form, or paste a whole config. Both write the same file.") {
            FakeWindow(title: "Edit Servers") {
                ConfigEditorView(store: store(), selectedIndex: 2).frame(width: 780, height: 650)
            }
            .padding(.top, 90)
            .padding(.trailing, 80)
        }
        try shot("4-first-run", caption: "Set up in seconds.",
                 detail: "Add a server, pick its services, and it's in your menu bar.") {
            FakeWindow(title: "Add Server") { AddServerView(store: store(SampleConfig.starter)) }
                .padding(.top, 150)
                .padding(.trailing, 120)
        }
    }
}

/// A neutral macOS-style desktop: wallpaper, a menu bar with dotlocal's icon, and content below it.
private struct Desktop<Content: View>: View {
    let dark: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: dark ? [Color(white: 0.20), Color(white: 0.07)] : [Color(white: 0.86), Color(white: 0.62)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color.white.opacity(dark ? 0.08 : 0.35), .clear], center: .init(x: 0.25, y: 0.3), startRadius: 0, endRadius: 520)
            VStack(spacing: 0) {
                MenuBar(dark: dark)
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct MenuBar: View {
    let dark: Bool

    /// The real menu bar template image from the asset catalog, loaded from the
    /// repo because SwiftPM doesn't compile the catalog.
    private var menuBarIcon: some View {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Assets.xcassets/MenuBarIcon.imageset/menubar@2x.png")
        let image = NSImage(contentsOf: url) ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return Image(nsImage: image)
    }

    var body: some View {
        HStack(spacing: 20) {
            Text("Finder").fontWeight(.bold)
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0) }
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            menuBarIcon
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.18)))
            Text("Sat 24 Oct  9:41")
        }
        .font(.system(size: 13))
        .foregroundStyle(dark ? Color.white : Color.black)
        .padding(.horizontal, 16)
        .frame(height: 26)
        .background(dark ? Color.black.opacity(0.45) : Color.white.opacity(0.55))
    }
}

/// The dropdown's rounded, shadowed panel.
private struct MenuPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }
}

/// A window with a title bar and traffic lights.
private struct FakeWindow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                    Spacer()
                }
                .frame(height: 12)
                .padding(.leading, 14)
            }
            .frame(height: 30)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            content
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .fixedSize()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }
}
