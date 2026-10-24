import AppKit
import UniformTypeIdentifiers

// System wiring: thin calls into AppKit (alerts, file panels, NSWorkspace,
// the pasteboard). Excluded from the coverage target because it only runs
// with a person at the screen; the logic that decides when to call it is tested.

extension EditorPrompts {
    static let system = EditorPrompts(
        confirmDroppingComments: {
            let skipKey = "SkipCommentWarning"
            if UserDefaults.standard.bool(forKey: skipKey) { return true }
            let alert = NSAlert()
            alert.messageText = "Saving here removes the comments in your config"
            alert.informativeText = "The Servers tab rewrites servers.yaml from the form. To keep your comments, make this change in the YAML tab instead."
            alert.addButton(withTitle: "Save Anyway")
            alert.addButton(withTitle: "Cancel")
            alert.showsSuppressionButton = true
            let confirmed = alert.runModal() == .alertFirstButtonReturn
            if confirmed && alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: skipKey)
            }
            return confirmed
        },
        chooseFileToImport: {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.yaml, .plainText]
            panel.allowsOtherFileTypes = true
            panel.canChooseDirectories = false
            return panel.runModal() == .OK ? panel.url : nil
        },
        chooseExportDestination: {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "servers.yaml"
            panel.allowedContentTypes = [.yaml]
            return panel.runModal() == .OK ? panel.url : nil
        }
    )
}

extension ConfigStore {
    func openInEditor() {
        if !NSWorkspace.shared.open(fileURL) {
            let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
            NSWorkspace.shared.open([fileURL], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}

enum Launcher {
    static func open(_ service: Service, on server: Server) {
        guard let url = service.url(for: server) else {
            NSSound.beep()
            return
        }
        closeMenu()
        if !NSWorkspace.shared.open(url) {
            NSSound.beep()
        }
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func closeMenu() {
        NSApp.keyWindow?.close()
    }
}
