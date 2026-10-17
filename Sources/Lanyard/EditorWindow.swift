import AppKit
import SwiftUI

/// A plain AppKit window hosting the editor, which behaves predictably
/// for a menu-bar-only app (SwiftUI's Window scene can auto-open at launch).
final class EditorWindowController {
    static let shared = EditorWindowController()
    private var window: NSWindow?

    func show(store: ConfigStore) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Lanyard"
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        guard let window else { return }
        if !window.isVisible {
            // Fresh view each time it opens, so it starts from what's on disk.
            window.contentView = NSHostingView(rootView: ConfigEditorView().environmentObject(store))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
