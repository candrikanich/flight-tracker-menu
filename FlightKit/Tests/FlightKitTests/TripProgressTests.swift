import Foundation
import Testing
@testable import FlightKit

/// Along the equator a degree of longitude is about 69 miles, so the expected numbers are easy to check.
@Suite struct TripProgressTests {
    func airport(_ code: String, longitude: Double) -> Airport {
        Airport(iata: code, icao: "K" + code, name: code, city: nil,
                coordinate: Coordinate(latitude: 0, longitude: longitude))
    }

    func progress(trip degrees: Double, at longitude: Double) -> String? {
        let route = Route(airlineName: nil, origin: airport("AAA", longitude: 0),
                          destination: airport("BBB", longitude: degrees))
        let line = Formatting.routeCodes(route, position: Coordinate(latitude: 0, longitude: longitude))
        let prefix = "AAA → BBB"
        return line == prefix ? nil : String(line.dropFirst(prefix.count + " · ".count))
    }

    @Test func earlyInTheTripSaysOnlyTheDistance() {
        #expect(progress(trip: 10, at: 1) == "620 mi to go")
    }

    @Test func midwaySaysAboutHalfway() {
        #expect(progress(trip: 10, at: 5) == "350 mi to go · about halfway")
    }

    @Test func lateInTheTripSaysNearlyThere() {
        #expect(progress(trip: 10, at: 9) == "70 mi to go · nearly there")
    }

    /// The status line already says "Arriving CLE"; a countdown in the last miles would only twitch.
    @Test func theLastFewMilesSayNothing() {
        #expect(progress(trip: 10, at: 9.8) == nil)
    }

    @Test func longTripsGroupThousands() {
        #expect(progress(trip: 20, at: 1) == "1,310 mi to go")
    }

    /// Routes may run up to 50 NM past either end; the miles are still from the plane, so they stay true.
    @Test func pastTheDestinationStillCountsTheMilesBack() {
        #expect(progress(trip: 10, at: 10.5) == "30 mi to go · nearly there")
    }

    @Test func aZeroLengthRouteSaysNothing() {
        #expect(progress(trip: 0, at: 1) == nil)
    }

    /// A stale card's countdown would sit frozen while sounding live, so it isn't shown.
    @Test func noPositionMeansJustTheCodes() {
        let route = Route(airlineName: nil, origin: airport("AAA", longitude: 0),
                          destination: airport("BBB", longitude: 10))
        #expect(Formatting.routeCodes(route, position: nil) == "AAA → BBB")
        #expect(Formatting.spokenRouteCodes(route, position: nil) == "AAA to BBB")
    }

    @Test func voiceOverHearsWordsNotSymbols() {
        let route = Route(airlineName: nil, origin: airport("AAA", longitude: 0),
                          destination: airport("BBB", longitude: 20))
        #expect(Formatting.spokenRouteCodes(route, position: Coordinate(latitude: 0, longitude: 1))
            == "AAA to BBB, 1,310 miles to go")
        #expect(Formatting.spokenRouteCodes(route, position: Coordinate(latitude: 0, longitude: 10))
            == "AAA to BBB, 690 miles to go, about halfway")
    }

    @Test func theCodesLineCarriesIt() {
        let route = Route(airlineName: nil, origin: airport("AAA", longitude: 0),
                          destination: airport("BBB", longitude: 10))
        #expect(Formatting.routeCodes(route, position: Coordinate(latitude: 0, longitude: 5))
            == "AAA → BBB · 350 mi to go · about halfway")
        #expect(Formatting.routeCodes(route, position: Coordinate(latitude: 0, longitude: 9.8)) == "AAA → BBB")
    }
}
