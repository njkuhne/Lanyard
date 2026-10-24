import AppKit
import SwiftUI
import XCTest

enum SnapshotAppearance {
    case light, dark

    var nsAppearance: NSAppearance {
        NSAppearance(named: self == .light ? .aqua : .darkAqua)!
    }
}

/// Renders `view` in an offscreen window and compares it with
/// `__Snapshots__/<name>.png` next to the calling test file.
/// A missing reference is recorded (and the test fails once so it gets noticed).
/// Set RECORD_SNAPSHOTS=1 to re-record everything after an intended UI change.
@MainActor
func assertSnapshot<V: View>(
    _ view: V,
    named name: String,
    width: CGFloat,
    height: CGFloat? = nil,
    appearance: SnapshotAppearance = .light,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let png = render(view, width: width, height: height, appearance: appearance) else {
        XCTFail("Couldn't render \(name)", file: file, line: line)
        return
    }

    let testDir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
    let reference = testDir.appendingPathComponent("__Snapshots__/\(name).png")
    let fm = FileManager.default

    if ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil || !fm.fileExists(atPath: reference.path) {
        try? fm.createDirectory(at: reference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png.write(to: reference)
        XCTFail("Recorded snapshot \(name). Check \(reference.path), then re-run.", file: file, line: line)
        return
    }

    guard let expected = try? Data(contentsOf: reference),
          let difference = SnapshotDiff.fractionDifferent(expected, png) else {
        XCTFail("Couldn't read reference \(reference.path)", file: file, line: line)
        return
    }
    if difference > 0.001 {
        // Package root is two levels above Tests/LanyardTests.
        let failures = testDir.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/snapshot-failures")
        try? fm.createDirectory(at: failures, withIntermediateDirectories: true)
        let actual = failures.appendingPathComponent("\(name).png")
        try? png.write(to: actual)
        let percent = String(format: "%.2f%%", difference * 100)
        XCTFail("\(name) differs from its reference by \(percent). Actual: \(actual.path)", file: file, line: line)
    }
}

@MainActor
func render<V: View>(_ view: V, width: CGFloat, height: CGFloat?, appearance: SnapshotAppearance) -> Data? {
    let host = NSHostingView(rootView: view)
    host.appearance = appearance.nsAppearance

    var size = CGSize(width: width, height: height ?? 100)
    if height == nil {
        host.frame = CGRect(origin: .zero, size: size)
        size.height = ceil(host.fittingSize.height)
    }

    let window = NSWindow(
        contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    window.appearance = appearance.nsAppearance
    window.contentView = host
    host.frame = CGRect(origin: .zero, size: size)
    defer { window.close() }

    // Let SwiftUI run onAppear and settle state before capturing.
    for _ in 0..<6 {
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])
}

private enum SnapshotDiff {
    /// Share of pixels that differ noticeably, or nil if either image can't be decoded.
    /// Images of different sizes count as entirely different.
    static func fractionDifferent(_ a: Data, _ b: Data) -> Double? {
        guard let pa = pixels(a), let pb = pixels(b) else { return nil }
        guard pa.width == pb.width, pa.height == pb.height else { return 1 }
        var differing = 0
        for i in stride(from: 0, to: pa.bytes.count, by: 4) {
            for c in 0..<4 where abs(Int(pa.bytes[i + c]) - Int(pb.bytes[i + c])) > 8 {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(pa.width * pa.height)
    }

    private static func pixels(_ data: Data) -> (width: Int, height: Int, bytes: [UInt8])? {
        guard let image = NSBitmapImageRep(data: data)?.cgImage else { return nil }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (width, height, bytes) : nil
    }
}
