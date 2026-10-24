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
        if service.kind == .app {
            guard let bundle = service.bundle,
                  let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
                NSSound.beep()
                return
            }
            closeMenu()
            let configuration = NSWorkspace.OpenConfiguration()
            if let url = service.url(for: server) {
                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration)
            } else {
                NSWorkspace.shared.openApplication(at: app, configuration: configuration)
            }
            return
        }
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

/// Looks up installed apps for `app` services.
enum AppInfo {
    static func url(for bundle: String) -> URL? {
        bundle.isEmpty ? nil : NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
    }

    static func name(for bundle: String) -> String {
        guard let url = url(for: bundle) else { return bundle }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for bundle: String) -> NSImage? {
        url(for: bundle).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    /// Asks for an app in /Applications and returns its bundle identifier.
    static func choose() -> String? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }
}
