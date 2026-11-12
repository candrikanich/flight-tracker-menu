import Foundation
import Testing
@testable import FlightKit

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

private func at(day: Int = 12, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

private func pass(_ seen: Date, callsign: String? = "UAL1365", route: Route? = nil) -> Pass {
    let aircraft = plane(callsign: callsign)
    return Pass(FlightTracker.Sighting(
        plane: NearbyPlane(aircraft: aircraft, heightAboveHomeFeet: 2_100, distanceMiles: 0.4),
        route: route,
        phase: .descending,
        seenAt: seen
    ))
}

@Suite struct DailyTallyTests {
    private let now = at(21, 30)

    @Test func countsOnlyPassesThatStartedToday() {
        let passes = [pass(at(day: 11, 23, 50)), pass(at(0, 5)), pass(at(8)), pass(at(20))]

        #expect(DailyTally(passes: passes, on: now, calendar: calendar).count == 3)
    }

    @Test func aQuietDayHasNothingToHighlight() {
        let tally = DailyTally(passes: [pass(at(day: 11, 18))], on: now, calendar: calendar)

        #expect(tally == DailyTally(count: 0, busiestHour: nil, topAirline: nil))
    }

    @Test func busiestHourIsTheHourWithTheMostPasses() {
        let passes = [pass(at(9)), pass(at(18, 10)), pass(at(18, 50)), pass(at(19, 5))]

        #expect(DailyTally(passes: passes, on: now, calendar: calendar).busiestHour == at(18))
    }

    @Test func noBusiestHourWhenNoHourStandsOut() {
        let oneEach = [pass(at(9)), pass(at(18))]
        let tied = [pass(at(9)), pass(at(9, 30)), pass(at(18)), pass(at(18, 30))]

        #expect(DailyTally(passes: oneEach, on: now, calendar: calendar).busiestHour == nil)
        #expect(DailyTally(passes: tied, on: now, calendar: calendar).busiestHour == nil)
    }

    @Test func topAirlineIsTheMostCommonOne() {
        let passes = [pass(at(8)), pass(at(9), callsign: "UAL22"), pass(at(10), callsign: "AAL3")]

        #expect(DailyTally(passes: passes, on: now, calendar: calendar).topAirline == "United Airlines")
    }

    @Test func routeAirlineCountsWhenTheCallsignIsUnknown() {
        let passes = [pass(at(8), callsign: "XYZ1", route: cleToEwr), pass(at(9))]

        #expect(DailyTally(passes: passes, on: now, calendar: calendar).topAirline == "United Airlines")
    }

    @Test func noTopAirlineWhenNoneStandsOut() {
        let single = [pass(at(8))]
        let tied = [pass(at(8)), pass(at(9)), pass(at(10), callsign: "AAL3"), pass(at(11), callsign: "AAL4")]
        let unknown = [pass(at(8), callsign: nil), pass(at(9), callsign: nil)]

        #expect(DailyTally(passes: single, on: now, calendar: calendar).topAirline == nil)
        #expect(DailyTally(passes: tied, on: now, calendar: calendar).topAirline == nil)
        #expect(DailyTally(passes: unknown, on: now, calendar: calendar).topAirline == nil)
    }

    @Test func headlineCountsPlanes() {
        #expect(Formatting.tallyHeadline(count: 1) == "1 plane over you today")
        #expect(Formatting.tallyHeadline(count: 23) == "23 planes over you today")
    }

    @Test func detailsNameTheBusiestHourAndAirline() {
        let both = DailyTally(count: 5, busiestHour: at(18), topAirline: "United Airlines")
        let hourOnly = DailyTally(count: 3, busiestHour: at(7), topAirline: nil)
        let neither = DailyTally(count: 1, busiestHour: nil, topAirline: nil)

        #expect(
            Formatting.tallyDetails(both, calendar: calendar) == "Busiest around 6\u{202F}PM · Mostly United Airlines"
        )
        #expect(Formatting.tallyDetails(hourOnly, calendar: calendar) == "Busiest around 7\u{202F}AM")
        #expect(Formatting.tallyDetails(neither, calendar: calendar) == nil)
    }
}
