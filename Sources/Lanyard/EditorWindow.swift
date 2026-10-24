import AppKit
import SwiftUI

/// Lets a window ask its SwiftUI editor whether it has unsaved changes, and save them.
final class EditorSession {
    weak var window: NSWindow?
    var save: () -> Bool = { true }
    var isDirty = false {
        didSet { window?.isDocumentEdited = isDirty }
    }
}

/// A plain AppKit window hosting one of the editors, which behaves predictably
/// for a menu-bar-only app (SwiftUI's Window scene can auto-open at launch).
final class EditorWindowController: NSObject, NSWindowDelegate {
    static let servers = EditorWindowController(title: "Edit Servers", size: NSSize(width: 780, height: 560)) {
        AnyView(ConfigEditorView(store: $0, session: $1))
    }
    static let yaml = EditorWindowController(title: "Edit YAML", size: NSSize(width: 640, height: 600)) {
        AnyView(YAMLEditorView(store: $0, session: $1))
    }

    private let title: String
    private let size: NSSize
    private let makeView: (ConfigStore, EditorSession) -> AnyView
    private var window: NSWindow?
    private var session = EditorSession()

    private init(title: String, size: NSSize, makeView: @escaping (ConfigStore, EditorSession) -> AnyView) {
        self.title = title
        self.size = size
        self.makeView = makeView
    }

    func show(store: ConfigStore) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = title
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
            window.contentView = NSHostingView(rootView: makeView(store, session))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ window: NSWindow) -> Bool {
        guard session.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save your changes?"
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
