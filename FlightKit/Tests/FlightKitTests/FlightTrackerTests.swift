import Foundation
import Testing
@testable import FlightKit

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_794_423_454)

    var now: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date += seconds } }
}

private func feedJSON(_ planes: [(hex: String, callsign: String, altitude: Int, milesNorth: Double)]) -> Data {
    let records = planes.map { plane in
        let position = north(of: homeAtSeaLevel.coordinate, miles: plane.milesNorth)
        return """
        {"hex":"\(plane.hex)","flight":"\(plane.callsign) ","alt_baro":\(plane.altitude),"category":"A3",\
        "lat":\(position.latitude),"lon":\(position.longitude)}
        """
    }
    return Data(#"{"aircraft":[\#(records.joined(separator: ","))]}"#.utf8)
}

@MainActor
@Suite struct FlightTrackerTests {
    let http = StubHTTP()
    let clock = TestClock()
    let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    func makeTracker(quietHours: QuietHours = .default) -> FlightTracker {
        let clock = clock
        let tracker = FlightTracker(
            feed: FeedClient(fetch: http.fetch),
            routes: RouteClient(fetch: http.fetch),
            now: { clock.now },
            calendar: newYork
        )
        tracker.configure(home: homeAtSeaLevel, criteria: NearbyCriteria(filter: .airport), quietHours: quietHours)
        return tracker
    }

    func serveFeed(_ planes: [(hex: String, callsign: String, altitude: Int, milesNorth: Double)]) {
        http.on("adsb.fi", body: feedJSON(planes))
    }

    func requestCount(_ match: String) -> Int {
        http.requests.filter { $0.url?.absoluteString.contains(match) == true }.count
    }

    @Test func currentIsTheCloserOfTwoQualifyingPlanes() async {
        serveFeed([("far", "UAL1", 2_000, 1.2), ("near", "UAL2", 2_000, 0.3)])
        let tracker = makeTracker()
        await tracker.tick()
        #expect(tracker.current?.plane.aircraft.hex == "near")
        #expect(tracker.status == .idle)
    }

    @Test func planeLeavingRangeClearsCurrentButKeepsLastSeen() async {
        serveFeed([("near", "UAL2", 2_000, 0.3)])
        let tracker = makeTracker()
        await tracker.tick()
        serveFeed([("near", "UAL2", 2_000, 4)])
        await tracker.tick()
        #expect(tracker.current == nil)
        #expect(tracker.lastSeen?.plane.aircraft.hex == "near")
    }

    @Test func quietHoursMakeNoRequests() async {
        serveFeed([("near", "UAL2", 2_000, 0.3)])
        let allDay = QuietHours(isEnabled: true, startMinutes: 0, endMinutes: 24 * 60 - 1)
        let tracker = makeTracker(quietHours: allDay)
        clock.advance(-clock.now.timeIntervalSince(newYork.startOfDay(for: clock.now)) + 12 * 3_600)
        await tracker.tick()
        #expect(http.requests.isEmpty)
        #expect(tracker.status == .quiet)
        #expect(tracker.current == nil)
    }

    @Test func withoutAHomeTheTrackerSaysSoInsteadOfLookingIdle() async {
        serveFeed([("near", "UAL2", 2_000, 0.3)])
        let tracker = makeTracker()
        tracker.configure(home: nil, criteria: NearbyCriteria(filter: .airport), quietHours: .default)
        await tracker.tick()
        #expect(http.requests.isEmpty)
        #expect(tracker.status == .needsHome)
        #expect(tracker.current == nil)
    }

    @Test func failuresBackOffThenRecover() async {
        http.on("adsb.fi", status: 503)
        let tracker = makeTracker()
        #expect(tracker.nextDelay == .seconds(5))
        var delays: [Duration] = []
        for _ in 0..<4 {
            await tracker.tick()
            delays.append(tracker.nextDelay)
        }
        #expect(delays == [.seconds(10), .seconds(20), .seconds(60), .seconds(60)])
        #expect(tracker.status == .offline)

        serveFeed([])
        await tracker.tick()
        #expect(tracker.nextDelay == .seconds(5))
        #expect(tracker.status == .idle)
    }

    @Test func samePlaneIsLookedUpAndAnnouncedOnce() async throws {
        serveFeed([("ual", "UAL1365", 2_000, 0.3)])
        http.on("adsbdb.com", body: try fixture("adsbdb-unknown"))
        http.on("adsb.lol", body: try fixture("adsblol-UAL1365"))
        let tracker = makeTracker()
        var announced: [FlightTracker.Sighting] = []
        tracker.onNewPlane = { announced.append($0) }

        for _ in 0..<3 {
            await tracker.tick()
            clock.advance(5)
        }

        #expect(requestCount("adsbdb.com") == 1)
        #expect(requestCount("adsb.lol") == 1)
        #expect(announced.count == 1)
        #expect(announced.first?.route?.origin.iata == "SNA")
        #expect(tracker.current?.route?.destination.iata == "EWR")
    }

    @Test func planeReturningAfterTwoMinutesIsAnnouncedAgain() async {
        let tracker = makeTracker()
        var announcements = 0
        tracker.onNewPlane = { _ in announcements += 1 }

        serveFeed([("ual", "N12345", 2_000, 0.3)])
        await tracker.tick()
        serveFeed([])
        clock.advance(90)
        await tracker.tick()
        serveFeed([("ual", "N12345", 2_000, 0.3)])
        clock.advance(20)
        await tracker.tick()
        #expect(announcements == 1)

        serveFeed([])
        clock.advance(5)
        await tracker.tick()
        clock.advance(180)
        serveFeed([("ual", "N12345", 2_000, 0.3)])
        await tracker.tick()
        #expect(announcements == 2)
    }

    @Test func planeStillInRangeWhileAnotherIsCloserIsNotAnnouncedAgain() async {
        let tracker = makeTracker()
        var announced: [String] = []
        tracker.onNewPlane = { announced.append($0.plane.aircraft.hex) }

        serveFeed([("heli", "N12345", 1_000, 1.0)])
        await tracker.tick()
        for _ in 0..<36 {
            clock.advance(5)
            serveFeed([("heli", "N12345", 1_000, 1.0), ("jet", "N67890", 2_000, 0.2)])
            await tracker.tick()
        }
        clock.advance(5)
        serveFeed([("heli", "N12345", 1_000, 1.0)])
        await tracker.tick()

        #expect(announced == ["heli", "jet"])
    }

    @Test func cachedRouteIsLookedUpAgainAfterSixHours() async throws {
        serveFeed([("ual", "UAL1365", 2_000, 0.3)])
        http.on("adsbdb.com", body: try fixture("adsbdb-unknown"))
        let tracker = makeTracker()
        await tracker.tick()
        clock.advance(5 * 3_600)
        await tracker.tick()
        #expect(requestCount("adsbdb.com") == 1)

        clock.advance(3_600 + 1)
        await tracker.tick()
        #expect(requestCount("adsbdb.com") == 2)
    }

    @Test func missingRouteLeavesRouteNil() async {
        serveFeed([("ual", "UAL1365", 2_000, 0.3)])
        let tracker = makeTracker()
        await tracker.tick()
        #expect(tracker.current != nil)
        #expect(tracker.current?.route == nil)
        #expect(tracker.current?.phase == .passingOver)
    }

    @Test func routeLookupFailureIsRetriedAfterAMinuteNotEveryTick() async throws {
        serveFeed([("ual", "UAL1365", 2_000, 0.3)])
        http.on("adsbdb.com", status: 503)
        let tracker = makeTracker()
        await tracker.tick()
        #expect(tracker.current?.route == nil)
        #expect(tracker.status == .idle)

        http.on("adsbdb.com", body: try fixture("adsbdb-unknown"))
        http.on("adsb.lol", body: try fixture("adsblol-UAL1365"))
        clock.advance(5)
        await tracker.tick()
        #expect(requestCount("adsbdb.com") == 1)
        #expect(tracker.current?.route == nil)

        clock.advance(60)
        await tracker.tick()
        #expect(tracker.current?.route?.origin.iata == "SNA")
    }

    @Test func nothingHappensBeforeAHomeIsSet() async {
        let tracker = FlightTracker(feed: FeedClient(fetch: http.fetch), routes: RouteClient(fetch: http.fetch))
        await tracker.tick()
        #expect(http.requests.isEmpty)
    }
}
