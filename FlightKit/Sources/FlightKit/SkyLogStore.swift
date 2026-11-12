import Foundation
import OSLog

/// Keeps the sky log in a JSON file on this Mac.
public struct SkyLogStore: Sendable {
    public let fileURL: URL
    private static let logger = Logger(subsystem: "com.andrikanich.Overflight", category: "SkyLog")

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Inside the app's sandbox container, so nothing else on the Mac reads or writes it.
    public static let standard = SkyLogStore(
        fileURL: URL.applicationSupportDirectory.appending(path: "Overflight/sky-log.json")
    )

    /// A missing file is a first launch. Any other failure moves the file aside under its own name, so a
    /// bad file can't block logging and neither the next save nor a later failure can overwrite it.
    public func load() -> SkyLog {
        do {
            return try JSONDecoder().decode(SkyLog.self, from: Data(contentsOf: fileURL))
        } catch CocoaError.fileReadNoSuchFile {
            return SkyLog()
        } catch {
            Self.logger.error("Sky log unreadable, starting fresh: \(error.localizedDescription)")
            let aside = fileURL.deletingLastPathComponent()
                .appending(path: "sky-log.unreadable-\(UUID().uuidString).json")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            return SkyLog()
        }
    }

    public func save(_ log: SkyLog) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(log).write(to: fileURL, options: .atomic)
    }
}
