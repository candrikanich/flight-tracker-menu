import Foundation
import Testing
@testable import FlightKit

@Suite struct SkyLogStoreTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "SkyLogStoreTests-\(UUID().uuidString)")
    var store: SkyLogStore { SkyLogStore(fileURL: folder.appending(path: "Overflight/sky-log.json")) }

    private func logWithOnePass() -> SkyLog {
        var log = SkyLog()
        let aircraft = plane()
        log.record(FlightTracker.Sighting(
            plane: NearbyPlane(aircraft: aircraft, heightAboveHomeFeet: 2_100, distanceMiles: 0.4),
            route: cleToEwr,
            phase: .departing,
            seenAt: Date(timeIntervalSince1970: 1_794_423_454)
        ), startsNewPass: true)
        return log
    }

    @Test func firstLaunchStartsWithAnEmptyLog() {
        #expect(store.load() == SkyLog())
    }

    @Test func savedLogLoadsBack() throws {
        let log = logWithOnePass()
        try store.save(log)
        #expect(store.load() == log)
    }

    private func asideFiles() throws -> [URL] {
        let folder = store.fileURL.deletingLastPathComponent()
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("sky-log.unreadable") }
    }

    private func writeCorruptFile(_ contents: String) throws {
        let folder = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: store.fileURL)
    }

    @Test func unreadableFileIsMovedAsideNotLost() throws {
        try writeCorruptFile("not json")

        #expect(store.load() == SkyLog())

        let aside = try asideFiles()
        #expect(aside.count == 1)
        #expect(try aside.first.map { try Data(contentsOf: $0) } == Data("not json".utf8))
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    @Test func aSecondUnreadableFileKeepsTheFirstOne() throws {
        try writeCorruptFile("first")
        _ = store.load()
        try writeCorruptFile("second")
        _ = store.load()

        let contents = try asideFiles().map { String(decoding: try Data(contentsOf: $0), as: UTF8.self) }
        #expect(Set(contents) == ["first", "second"])
    }
}
