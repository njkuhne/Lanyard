import AppKit
import SwiftUI

@main
struct DotlocalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ConfigStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(store)
        } label: {
            // Template image rendered by scripts/make-icon.swift from the icon spec.
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only. Info.plist sets LSUIElement for the bundled app;
        // this also hides the Dock icon when running via `swift run` or Xcode.
        NSApp.setActivationPolicy(.accessory)
        AppearanceMode.current.apply()
        if ConfigStore.shared.createdStarterFile {
            EditorWindowController.addServer.show(store: .shared)
        }
    }
}

extension ConfigStore {
    static let shared = ConfigStore()
}
