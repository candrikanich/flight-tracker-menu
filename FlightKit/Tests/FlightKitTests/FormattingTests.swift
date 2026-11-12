import Foundation
import Testing
@testable import FlightKit

@Suite struct LookupsTests {
    @Test func airlineFromCallsignPrefix() {
        #expect(Lookups.airline(forCallsign: "UAL1365") == Lookups.Airline(name: "United Airlines", iata: "UA"))
        #expect(Lookups.airline(forCallsign: "SKW4752")?.iata == "OO")
    }

    @Test func registrationCallsignHasNoAirline() {
        #expect(Lookups.airline(forCallsign: "N5955K") == nil)
    }

    @Test func unknownPrefixHasNoAirline() {
        #expect(Lookups.airline(forCallsign: "ERY917") == nil)
    }

    @Test(arguments: [
        ("UAL", "UA"), ("AAL", "AA"), ("DAL", "DL"), ("SWA", "WN"), ("JBU", "B6"), ("NKS", "NK"),
        ("FFT", "F9"), ("ASA", "AS"), ("SKW", "OO"), ("RPA", "YX"), ("ENY", "MQ"), ("EDV", "9E"),
        ("JIA", "OH"), ("PDT", "PT"), ("ASH", "YV"), ("GJS", "G7"), ("AWI", "ZW"), ("BRE", "MX"),
        ("AAY", "G4"), ("FDX", "FX"), ("UPS", "5X"), ("ACA", "AC"), ("JZA", "QK"),
    ])
    func everyRequiredAirlineIsInTheTable(prefix: String, iata: String) {
        #expect(Lookups.airline(forCallsign: "\(prefix)123")?.iata == iata)
    }

    @Test(arguments: [
        ("A319", 128), ("A320", 150), ("A321", 190), ("A20N", 150), ("A21N", 196), ("B737", 143),
        ("B738", 166), ("B739", 179), ("B38M", 166), ("B39M", 178), ("B752", 176), ("B763", 211),
        ("B772", 300), ("B789", 257), ("CRJ2", 50), ("CRJ7", 70), ("CRJ9", 76), ("E145", 50),
        ("E170", 70), ("E75L", 76), ("E75S", 76), ("BCS1", 109), ("BCS3", 130), ("DH8D", 74),
    ])
    func typicalSeats(typeCode: String, seats: Int) {
        #expect(Lookups.typicalSeats(forTypeCode: typeCode) == seats)
    }

    @Test func unknownTypeHasNoSeatEstimate() {
        #expect(Lookups.typicalSeats(forTypeCode: "PRM1") == nil)
    }
}

@Suite struct FormattingTests {
    func nearby(_ aircraft: Aircraft, miles: Double = 0.4, feet: Int = 2_100) -> NearbyPlane {
        NearbyPlane(aircraft: aircraft, heightAboveHomeFeet: feet, distanceMiles: miles)
    }

    @Test func menuBarTextWithRoute() {
        #expect(Formatting.menuBarText(nearby(plane()), route: cleToEwr) == "✈︎ UA1365 → EWR · 0.4 mi · 2,100 ft")
    }

    @Test func menuBarTextWithoutRoute() {
        #expect(Formatting.menuBarText(nearby(plane()), route: nil) == "✈︎ UA1365 · 0.4 mi · 2,100 ft")
    }

    @Test func menuBarTextFallsBackToRawCallsignThenRegistration() {
        let charter = plane(callsign: "ERY917")
        #expect(Formatting.menuBarText(nearby(charter, miles: 1.26, feet: 12_345), route: nil) == "✈︎ ERY917 · 1.3 mi · 12,345 ft")
        let private_ = plane(callsign: nil, registration: "N100WE")
        #expect(Formatting.menuBarText(nearby(private_), route: nil) == "✈︎ N100WE · 0.4 mi · 2,100 ft")
    }

    @Test func destinationFallsBackToICAO() {
        let noIATA = Route(airlineName: nil, origin: cleToEwr.origin, destination: airport("KXYZ", iata: nil, city: "Nowhere"))
        #expect(Formatting.menuBarText(nearby(plane()), route: noIATA) == "✈︎ UA1365 → KXYZ · 0.4 mi · 2,100 ft")
    }

    @Test func flightTitlePrefersTheRouteAirlineThenTheCallsignPrefix() {
        #expect(Formatting.flightTitle(callsign: "UAL1365", registration: nil, routeAirline: "United") == "United UA1365")
        #expect(Formatting.flightTitle(callsign: "UAL1365", registration: nil, routeAirline: nil) == "United Airlines UA1365")
        #expect(Formatting.flightTitle(callsign: nil, registration: "N27733", routeAirline: nil) == "N27733")
    }

    @Test func placeNamesTheCityAndCode() {
        #expect(Formatting.place(cleToEwr.destination) == "Newark (EWR)")
        let noIata = Airport(iata: nil, icao: "KCGF", name: "Cuyahoga County", city: nil, coordinate: cle)
        #expect(Formatting.place(noIata) == "Cuyahoga County (KCGF)")
    }

    @Test func phaseReadsAsPlainWords() {
        #expect(Formatting.phase(.arriving) == "Arriving CLE")
        #expect(Formatting.phase(.passingOver) == "Passing over")
    }

    @Test func onlyEmergencySquawksGetALabel() {
        #expect(Formatting.emergency(squawk: "7700") == "Emergency squawk 7700")
        #expect(Formatting.emergency(squawk: "7600") == "Emergency squawk 7600 radio failure")
        #expect(Formatting.emergency(squawk: "1200") == nil)
        #expect(Formatting.emergency(squawk: nil) == nil)
    }

    @Test func flightLabelWithNothingKnown() {
        #expect(Formatting.flightLabel(callsign: nil, registration: nil) == "Unknown aircraft")
    }

    @Test func knotsToMph() {
        #expect(Formatting.mph(knots: 100) == 115)
    }

    @Test func mphNeverTrapsOnNonFiniteOrHugeInput() {
        #expect(Formatting.mph(knots: .infinity) == nil)
        #expect(Formatting.mph(knots: .nan) == nil)
        #expect(Formatting.mph(knots: 1e300) == nil)
    }
}

@Suite struct SummaryAndLastSeenTests {
    let near = NearbyPlane(aircraft: plane(), heightAboveHomeFeet: 2_100, distanceMiles: 0.4)

    @Test func summaryHasNoSymbolAndMenuBarTextAddsIt() {
        #expect(Formatting.summary(near, route: cleToEwr) == "UA1365 → EWR · 0.4 mi · 2,100 ft")
        #expect(Formatting.menuBarText(near, route: cleToEwr) == "✈︎ UA1365 → EWR · 0.4 mi · 2,100 ft")
    }

    @Test func lastSeenIsCoarseAndDoesNotCountSeconds() {
        let seen = Date(timeIntervalSince1970: 1_000_000)
        #expect(Formatting.lastSeen(seen, now: seen.addingTimeInterval(5)) == "Last seen just now")
        #expect(Formatting.lastSeen(seen, now: seen.addingTimeInterval(59)) == "Last seen just now")
        #expect(Formatting.lastSeen(seen, now: seen.addingTimeInterval(60)) == "Last seen 1 min ago")
        #expect(Formatting.lastSeen(seen, now: seen.addingTimeInterval(179)) == "Last seen 2 min ago")
        #expect(Formatting.lastSeen(seen, now: seen.addingTimeInterval(3_600)) == "Last seen 1 hr ago")
        #expect(Formatting.lastSeen(seen, now: seen.addingTimeInterval(3 * 3_600 + 1_000)) == "Last seen 3 hr ago")
    }
}
