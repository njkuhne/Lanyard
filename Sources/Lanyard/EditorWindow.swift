import AppKit
import SwiftUI

/// Lets a window talk to its SwiftUI editor: unsaved changes, saving, and selection.
final class EditorSession {
    weak var window: NSWindow?
    var save: () -> Bool = { true }
    var select: (Int) -> Void = { _ in }
    var isDirty = false {
        didSet { window?.isDocumentEdited = isDirty }
    }
}

/// A plain AppKit window hosting one of the editors, which behaves predictably
/// for a menu-bar-only app (SwiftUI's Window scene can auto-open at launch).
final class EditorWindowController: NSObject, NSWindowDelegate {
    static let servers = EditorWindowController(title: "Edit Servers", size: NSSize(width: 780, height: 560)) {
        AnyView(ConfigEditorView(store: $0, selectedIndex: $2, session: $1))
    }
    static let yaml = EditorWindowController(title: "Edit YAML", size: NSSize(width: 640, height: 600)) { store, session, _ in
        AnyView(YAMLEditorView(store: store, session: session))
    }
    static let addServer = EditorWindowController(title: "Add Server", size: NSSize(width: 440, height: 360), resizable: false) { store, session, _ in
        AnyView(AddServerView(
            store: store,
            close: { session.window?.close() },
            pasteYAML: {
                session.window?.close()
                EditorWindowController.yaml.show(store: store)
            }
        ))
    }

    private let title: String
    private let size: NSSize
    private let resizable: Bool
    private let makeView: (ConfigStore, EditorSession, Int?) -> AnyView
    private var window: NSWindow?
    private var session = EditorSession()

    private init(title: String, size: NSSize, resizable: Bool = true, makeView: @escaping (ConfigStore, EditorSession, Int?) -> AnyView) {
        self.title = title
        self.size = size
        self.resizable = resizable
        self.makeView = makeView
    }

    func show(store: ConfigStore, selectedIndex: Int? = nil) {
        if window == nil {
            var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
            if resizable { style.insert(.resizable) }
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
            window.title = title
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        guard let window else { return }
        if !window.isVisible && !window.isMiniaturized {
            // Fresh view each time it opens, so it starts from what's on disk.
            session = EditorSession()
            session.window = window
            window.isDocumentEdited = false
            let host = NSHostingView(rootView: makeView(store, session, selectedIndex))
            window.contentView = host
            if !resizable { window.setContentSize(host.fittingSize) }
            window.center()
        } else if let selectedIndex {
            session.select(selectedIndex)
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
