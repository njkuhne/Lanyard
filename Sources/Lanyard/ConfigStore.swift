import Combine
import Foundation

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

    /// True when this launch created the config file, i.e. the first run.
    private(set) var createdStarterFile = false

    /// Inside the sandbox container when sandboxed.
    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lanyard/servers.yaml")
    }

    init(fileURL: URL = ConfigStore.defaultFileURL) {
        self.fileURL = fileURL
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

    // MARK: - Private

    private func createSampleIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: fileURL.path) else { return }
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        createdStarterFile = (try? SampleConfig.starter.write(to: fileURL, atomically: true, encoding: .utf8)) != nil
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
