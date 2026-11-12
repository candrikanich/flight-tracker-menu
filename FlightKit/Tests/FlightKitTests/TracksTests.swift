import Foundation
import Testing
@testable import FlightKit

@Suite struct TracksTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    func at(_ hex: String, _ latitude: Double) -> Aircraft {
        Aircraft(hex: hex, altitudeFeet: 3_000, coordinate: Coordinate(latitude: latitude, longitude: -81.8))
    }

    @Test func recordsEachAircraftsPositionsInOrder() {
        var tracks = Tracks()
        tracks.record([at("a", 41.0), at("b", 42.0)], at: start)
        tracks.record([at("a", 41.1)], at: start.addingTimeInterval(5))

        #expect(tracks.path(for: "a").map(\.latitude) == [41.0, 41.1])
        #expect(tracks.path(for: "b").map(\.latitude) == [42.0])
        #expect(tracks.path(for: "unknown").isEmpty)
    }

    /// The feed repeats the last position when a plane goes quiet; that isn't movement.
    @Test func repeatedPositionIsNotAddedTwice() {
        var tracks = Tracks()
        tracks.record([at("a", 41.0)], at: start)
        tracks.record([at("a", 41.0)], at: start.addingTimeInterval(5))
        #expect(tracks.path(for: "a").count == 1)
    }

    @Test func longPathKeepsOnlyTheNewestPoints() {
        var tracks = Tracks()
        for step in 0..<(Tracks.maxPoints + 10) {
            tracks.record([at("a", 41.0 + Double(step) * 0.001)], at: start.addingTimeInterval(Double(step) * 5))
        }
        let path = tracks.path(for: "a")
        #expect(path.count == Tracks.maxPoints)
        #expect(path.first?.latitude == 41.0 + 10 * 0.001)
    }

    /// A stale card's plane icon is frozen where it was last seen, so its path must stop there too,
    /// even though the plane is still in the feed and its path keeps growing.
    @Test func pathCanBeCutAtTheMomentItWasLastSeen() {
        var tracks = Tracks()
        tracks.record([at("a", 41.0)], at: start)
        tracks.record([at("a", 41.1)], at: start.addingTimeInterval(5))
        tracks.record([at("a", 41.2)], at: start.addingTimeInterval(10))

        #expect(tracks.path(for: "a", through: start.addingTimeInterval(5)).map(\.latitude) == [41.0, 41.1])
        #expect(tracks.path(for: "a", through: start.addingTimeInterval(10)).count == 3)
    }

    /// A plane that left the feed and came back flew somewhere unseen; joining the two would draw a
    /// straight line it never flew.
    @Test func planeBackAfterAGapStartsAFreshPath() {
        var tracks = Tracks()
        tracks.record([at("a", 41.0)], at: start)
        tracks.record([at("a", 41.1)], at: start.addingTimeInterval(Tracks.maxGap))
        tracks.record([at("a", 41.5)], at: start.addingTimeInterval(Tracks.maxGap * 2 + 1))

        #expect(tracks.path(for: "a").map(\.latitude) == [41.5])
    }

    @Test func planesGoneForAWhileAreForgottenUnlessKept() {
        var tracks = Tracks()
        tracks.record([at("old", 41.0), at("shown", 41.5)], at: start)
        tracks.record([at("fresh", 42.0)], at: start.addingTimeInterval(Tracks.forgetAfter))
        tracks.prune(now: start.addingTimeInterval(Tracks.forgetAfter + 1), keeping: "shown")

        #expect(tracks.path(for: "old").isEmpty)
        #expect(tracks.path(for: "shown").count == 1)
        #expect(tracks.path(for: "fresh").count == 1)
    }
}

@Suite struct MapFramingTests {
    let home = Coordinate(latitude: 41.40, longitude: -81.90)

    func contains(_ region: MapFraming.Region, _ point: Coordinate) -> Bool {
        abs(point.latitude - region.center.latitude) <= region.latitudeDelta / 2
            && abs(point.longitude - region.center.longitude) <= region.longitudeDelta / 2
    }

    @Test func framesHomeThePlaneAndItsPath() {
        let plane = Coordinate(latitude: 41.45, longitude: -81.70)
        let path = [Coordinate(latitude: 41.30, longitude: -82.10), plane]
        let region = MapFraming.region(home: home, plane: plane, path: path)

        #expect(([home, plane] + path).allSatisfy { contains(region, $0) })
    }

    /// A plane right over the house must not zoom the map in to a single street.
    @Test func neverZoomsInTighterThanTheMinimumSpan() {
        let region = MapFraming.region(home: home, plane: home, path: [])
        let minimumLatitudeDelta = MapFraming.minimumSpanMiles / Geo.milesPerDegreeLatitude

        #expect(region.center == home)
        #expect(region.latitudeDelta >= minimumLatitudeDelta)
        #expect(region.longitudeDelta > region.latitudeDelta)
    }
}
