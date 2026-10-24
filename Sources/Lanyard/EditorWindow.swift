import AppKit
import SwiftUI

/// Lets the window ask the SwiftUI editor whether it has unsaved changes, and save them.
final class EditorSession {
    weak var window: NSWindow?
    var save: () -> Bool = { true }
    var isDirty = false {
        didSet { window?.isDocumentEdited = isDirty }
    }
}

/// A plain AppKit window hosting the editor, which behaves predictably
/// for a menu-bar-only app (SwiftUI's Window scene can auto-open at launch).
final class EditorWindowController: NSObject, NSWindowDelegate {
    static let shared = EditorWindowController()
    private var window: NSWindow?
    private var session = EditorSession()

    func show(store: ConfigStore) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Edit Servers"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        guard let window else { return }
        if !window.isVisible && !window.isMiniaturized {
            // Fresh view each time it opens, so it starts from what's on disk.
            session = EditorSession()
            session.window = window
            window.isDocumentEdited = false
            window.contentView = NSHostingView(
                rootView: ConfigEditorView(session: session).environmentObject(store)
            )
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ window: NSWindow) -> Bool {
        guard session.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to your servers?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [session] response in
            switch response {
            case .alertFirstButtonReturn:
                if session.save() { window.close() }
            case .alertSecondButtonReturn:
                session.isDirty = false
                window.close()
            default:
                break
            }
        }
        return false
    }
}
