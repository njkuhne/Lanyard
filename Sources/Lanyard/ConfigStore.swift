import AppKit
import Foundation
import UniformTypeIdentifiers

/// Owns servers.yaml in Application Support: creates a sample on first launch,
/// parses it, and reloads automatically whenever it changes on disk.
/// When sandboxed (App Store), Application Support resolves inside the app's
/// container, so the same code works in both builds.
final class ConfigStore: ObservableObject {
    @Published private(set) var config = LanyardConfig()
    @Published private(set) var errorMessage: String?
    @Published private(set) var rawText = ""

    let fileURL: URL

    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pendingReload: DispatchWorkItem?

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = fileURL ?? support.appendingPathComponent("Lanyard/servers.yaml")
        createSampleIfNeeded()
        reload()
        // Watching the folder catches editors that save by replacing the file.
        directorySource = watch(self.fileURL.deletingLastPathComponent(), events: [.write, .rename, .delete])
    }

    func reload() {
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            rawText = text
            config = try ConfigParser.parse(text)
            errorMessage = nil
        } catch let error as ConfigError {
            // Keep showing the last good config alongside the error.
            errorMessage = error.message
        } catch {
            errorMessage = "Couldn't open \(fileURL.path): \(error.localizedDescription)"
        }

        // Re-attach to the file itself, since an atomic save gives it a new inode.
        fileSource?.cancel()
        fileSource = watch(fileURL, events: [.write, .extend, .rename, .delete])
    }

    func openInEditor() {
        if !NSWorkspace.shared.open(fileURL) {
            let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
            NSWorkspace.shared.open([fileURL], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Replaces the config with YAML from the clipboard, but only if it parses.
    func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            errorMessage = "The clipboard doesn't have any text in it."
            return
        }
        replaceConfig(with: text, source: "The clipboard")
    }

    /// Replaces the config with a YAML file the user picks, but only if it parses.
    func importFromFile() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Import Lanyard Config"
        panel.allowedContentTypes = [.yaml, .plainText]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            replaceConfig(with: text, source: url.lastPathComponent)
        } catch {
            errorMessage = "Couldn't read \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    func copyToClipboard() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Validates, then saves. Returns a human-readable error, or nil on success.
    @discardableResult
    func save(_ text: String) -> String? {
        do {
            _ = try ConfigParser.parse(text)
        } catch {
            return "Not saved. \(error.localizedDescription)"
        }
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            return "Couldn't save: \(error.localizedDescription)"
        }
        reload()
        return nil
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    // MARK: - Private

    private func replaceConfig(with text: String, source: String) {
        if let error = save(text) {
            errorMessage = "\(source): \(error)"
        }
    }

    private func createSampleIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: fileURL.path) else { return }
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? SampleConfig.text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func scheduleReload() {
        pendingReload?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.reload() }
        pendingReload = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func watch(_ url: URL, events: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let fd = Darwin.open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleReload() }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }
}
