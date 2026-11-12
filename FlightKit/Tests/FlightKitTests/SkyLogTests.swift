import Foundation
import Testing
@testable import FlightKit

private let start = Date(timeIntervalSince1970: 1_794_423_454)

private func sighting(
    hex: String = "abc123",
    milesNorth: Double = 0.4,
    altitudeFeet: Int = 2_100,
    route: Route? = nil,
    at offset: TimeInterval
) -> FlightTracker.Sighting {
    let aircraft = plane(hex: hex, altitudeFeet: altitudeFeet, milesNorth: milesNorth)
    return FlightTracker.Sighting(
        plane: NearbyPlane(aircraft: aircraft, heightAboveHomeFeet: altitudeFeet, distanceMiles: milesNorth),
        route: route,
        phase: .descending,
        seenAt: start + offset
    )
}

@Suite struct SkyLogTests {
    @Test func firstSightingStartsAPass() {
        var log = SkyLog()
        log.record(sighting(at: 0), startsNewPass: true)

        #expect(log.passes.count == 1)
        let pass = log.passes[0]
        #expect(pass.hex == "abc123")
        #expect(pass.callsign == "UAL1365")
        #expect(pass.typeCode == "B737")
        #expect(pass.firstSeen == start)
        #expect(pass.lastSeen == start)
    }

    @Test func repeatedSightingsOfOnePlaneBecomeOnePassWithItsClosestApproach() {
        var log = SkyLog()
        log.record(sighting(milesNorth: 1.2, altitudeFeet: 2_500, at: 0), startsNewPass: true)
        log.record(sighting(milesNorth: 0.3, altitudeFeet: 2_200, at: 5), startsNewPass: false)
        log.record(sighting(milesNorth: 0.9, altitudeFeet: 1_900, at: 10), startsNewPass: false)

        #expect(log.passes.count == 1)
        let pass = log.passes[0]
        #expect(pass.closestMiles == 0.3)
        #expect(pass.lowestHeightFeet == 1_900)
        #expect(pass.firstSeen == start)
        #expect(pass.lastSeen == start + 10)
    }

    @Test func samePlaneReturningAsANewPassGetsItsOwnEntry() {
        var log = SkyLog()
        log.record(sighting(at: 0), startsNewPass: true)
        log.record(sighting(at: FlightTracker.reannounceAfter + 1), startsNewPass: true)

        #expect(log.passes.count == 2)
    }

    @Test func differentPlanesAreSeparatePasses() {
        var log = SkyLog()
        log.record(sighting(hex: "aaa111", at: 0), startsNewPass: true)
        log.record(sighting(hex: "bbb222", at: 5), startsNewPass: true)
        log.record(sighting(hex: "aaa111", at: 10), startsNewPass: false)

        #expect(log.passes.map(\.hex) == ["aaa111", "bbb222"])
    }

    @Test func aRouteFoundLaterFillsInThePass() {
        var log = SkyLog()
        log.record(sighting(at: 0), startsNewPass: true)
        log.record(sighting(route: dfwToCle, at: 5), startsNewPass: false)
        log.record(sighting(at: 10), startsNewPass: false)

        #expect(log.passes[0].route == dfwToCle)
    }

    @Test func continuingSightingOfAPlaneNotYetLoggedStartsItsPass() {
        var log = SkyLog()
        log.record(sighting(at: 0), startsNewPass: false)

        #expect(log.passes.count == 1)
    }

    @Test func passesOlderThanThirtyDaysAreDropped() {
        var log = SkyLog()
        log.record(sighting(hex: "old", at: 0), startsNewPass: true)
        log.record(sighting(hex: "new", at: 30 * 86_400 + 60), startsNewPass: true)

        #expect(log.passes.map(\.hex) == ["new"])
    }

    @Test func survivesSavingAndLoading() throws {
        var log = SkyLog()
        log.record(sighting(route: cleToEwr, at: 0), startsNewPass: true)
        log.record(sighting(hex: "bbb222", at: 5), startsNewPass: true)

        let reloaded = try JSONDecoder().decode(SkyLog.self, from: JSONEncoder().encode(log))

        #expect(reloaded == log)
    }

    @Test func daysAreNewestFirstWithNewestPassesFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var log = SkyLog()
        log.record(sighting(hex: "day1a", at: 0), startsNewPass: true)
        log.record(sighting(hex: "day1b", at: 600), startsNewPass: true)
        log.record(sighting(hex: "day2", at: 86_400), startsNewPass: true)

        let days = log.days(calendar: calendar)

        #expect(days.map { $0.passes.map(\.hex) } == [["day2"], ["day1b", "day1a"]])
        #expect(days[0].day == calendar.startOfDay(for: start + 86_400))
    }
}

@Suite struct DayTitleTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    @Test func todayAndYesterdayAreNamed() {
        let now = start
        #expect(Formatting.dayTitle(now, now: now, calendar: calendar) == "Today")
        #expect(Formatting.dayTitle(now - 86_400, now: now, calendar: calendar) == "Yesterday")
    }

    @Test func olderDaysShowTheDate() {
        let title = Formatting.dayTitle(start - 3 * 86_400, now: start, calendar: calendar)
        #expect(title != "Today" && title != "Yesterday")
        #expect(!title.isEmpty)
    }
}
