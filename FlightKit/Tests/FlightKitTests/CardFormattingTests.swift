import Foundation
import Testing
@testable import FlightKit

@Suite struct CardFormattingTests {
    @Test func routeHeadlineUsesCitiesAndTheCodeLineUsesIATA() {
        #expect(Formatting.routeHeadline(dfwToCle) == "Dallas → Cleveland")
        #expect(Formatting.routeCodes(dfwToCle) == "DFW → CLE")
    }

    @Test func routeFallsBackToAirportNameAndICAO() {
        let field = Airport(
            iata: nil, icao: "KCGF", name: "Cuyahoga County", city: nil,
            coordinate: Coordinate(latitude: 0, longitude: 0)
        )
        let route = Route(airlineName: nil, origin: field, destination: dfwToCle.destination)
        #expect(Formatting.routeHeadline(route) == "Cuyahoga County → Cleveland")
        #expect(Formatting.routeCodes(route) == "KCGF → CLE")
    }

    @Test func identityKeepsTheFullAirlineName() {
        #expect(Formatting.flightIdentity(callsign: "SWA4479", registration: nil, routeAirline: nil)
            == "Southwest Airlines · WN4479")
        #expect(Formatting.flightIdentity(callsign: "UAL1365", registration: nil, routeAirline: "United")
            == "United · UA1365")
    }

    @Test func identityWithoutAnAirlineIsJustTheLabel() {
        #expect(Formatting.flightIdentity(callsign: "N5955K", registration: "N5955K", routeAirline: nil) == "N5955K")
        #expect(Formatting.flightIdentity(callsign: nil, registration: nil, routeAirline: nil) == "Unknown aircraft")
    }

    @Test func statsReadValueThenLabelAndSpeakInFullWords() {
        let aircraft = plane(callsign: "SWA4479")
        let speedy = Aircraft(
            hex: aircraft.hex, altitudeFeet: 2_000, groundSpeedKnots: 126.9, coordinate: aircraft.coordinate
        )
        let nearby = NearbyPlane(aircraft: speedy, heightAboveHomeFeet: 1_885, distanceMiles: 1.26)
        let stats = Formatting.stats(nearby, isStale: false)

        #expect(stats == [
            Formatting.Stat(value: "1,885 ft", label: "Above you", spoken: "1,885 feet above you"),
            Formatting.Stat(value: "1.3 mi", label: "Distance", spoken: "1.3 miles away"),
            Formatting.Stat(value: "146 mph", label: "Speed", spoken: "146 miles per hour"),
        ])
    }

    /// Never a zero standing in for a missing value.
    @Test func missingSpeedIsAnEmDashSpokenAsUnavailable() {
        let nearby = NearbyPlane(aircraft: plane(), heightAboveHomeFeet: 900, distanceMiles: 0.4)
        let stats = Formatting.stats(nearby, isStale: false)
        #expect(stats.last == Formatting.Stat(value: "—", label: "Speed", spoken: "Speed unavailable"))
    }

    /// "Above you" read on a stale card sounds current; the label says it's the height from that sighting.
    @Test func staleHeightLabelSaysItWasTheHeightThen() {
        let nearby = NearbyPlane(aircraft: plane(), heightAboveHomeFeet: 835, distanceMiles: 1.5)
        #expect(Formatting.stats(nearby, isStale: true).map(\.label) == ["Height above you", "Distance", "Speed"])
        #expect(Formatting.stats(nearby, isStale: false).map(\.label) == ["Above you", "Distance", "Speed"])
    }

    @Test func aircraftLineJoinsTypeAndRegistrationWhenKnown() {
        func line(type: String?, code: String?, registration: String?) -> String? {
            Formatting.aircraftLine(Aircraft(
                hex: "a", callsign: "SWA4479", registration: registration, typeCode: code, typeDescription: type,
                altitudeFeet: 1_000, coordinate: Coordinate(latitude: 0, longitude: 0)
            ))
        }
        #expect(line(type: "BOEING 737-700", code: "B737", registration: "N280WN") == "BOEING 737-700 · N280WN")
        #expect(line(type: nil, code: "B737", registration: nil) == "B737")
        #expect(line(type: nil, code: nil, registration: "N280WN") == "N280WN")
        #expect(line(type: nil, code: nil, registration: nil) == nil)
    }

    /// Without a callsign the registration is already the flight identity; saying it twice crowds the line.
    @Test func aircraftLineSkipsTheRegistrationWhenThereIsNoCallsign() {
        let aircraft = Aircraft(
            hex: "a", registration: "N158PH", typeCode: "CL35", typeDescription: "Bombardier Challenger 350",
            altitudeFeet: 1_000, coordinate: Coordinate(latitude: 0, longitude: 0)
        )
        #expect(Formatting.aircraftLine(aircraft) == "Bombardier Challenger 350")
    }

    /// Light aircraft usually broadcast their tail number as the callsign, so it's already the identity.
    @Test func aircraftLineSkipsTheRegistrationWhenItIsTheCallsign() {
        let aircraft = Aircraft(
            hex: "a", callsign: "N5955K", registration: "N5955K", typeDescription: "Cessna 172 Skyhawk",
            altitudeFeet: 1_000, coordinate: Coordinate(latitude: 0, longitude: 0)
        )
        #expect(Formatting.aircraftLine(aircraft) == "Cessna 172 Skyhawk")
    }

    @Test func builtLineCountsYearsAndHandlesSingularAndBrandNew() {
        #expect(Formatting.builtLine(year: 2007, currentYear: 2026) == "Built 2007 · 19 years old")
        #expect(Formatting.builtLine(year: 2025, currentYear: 2026) == "Built 2025 · 1 year old")
        #expect(Formatting.builtLine(year: 2026, currentYear: 2026) == "Built 2026")
        // A clock or database slightly ahead must not produce a negative age.
        #expect(Formatting.builtLine(year: 2027, currentYear: 2026) == "Built 2027")
    }

    @Test func seatsLineKeepsTheTildeAndQualifier() {
        #expect(Formatting.seatsLine(typeCode: "B737") == "~143 seats · typical capacity")
        #expect(Formatting.seatsLine(typeCode: "PRM1") == nil)
        #expect(Formatting.seatsLine(typeCode: nil) == nil)
    }

    /// Without a route, "Passing over" is only the fallback guess, not something the data says.
    @Test func statusLineOnlyShowsWhatTheDataSupports() {
        #expect(Formatting.status(.arriving, hasRoute: true) == "Arriving CLE")
        #expect(Formatting.status(.passingOver, hasRoute: true) == "Passing over")
        #expect(Formatting.status(.descending, hasRoute: false) == "Descending")
        #expect(Formatting.status(.passingOver, hasRoute: false) == nil)
    }

    @Test func freshnessSaysNearbyNowOnlyForTheCurrentPlane() {
        let seen = Date(timeIntervalSince1970: 1_000_000)
        let later = seen.addingTimeInterval(180)
        #expect(Formatting.freshness(seenAt: seen, isCurrent: true, status: .idle, now: later) == "Nearby now")
        #expect(Formatting.freshness(seenAt: seen, isCurrent: false, status: .idle, now: later)
            == "Last known position · 3 min ago")
    }

    /// A stale card must say why nothing is live, whatever the reason.
    @Test func staleFreshnessExplainsWhyNothingIsLive() {
        let seen = Date(timeIntervalSince1970: 1_000_000)
        func stale(_ status: FlightTracker.Status) -> String {
            Formatting.freshness(seenAt: seen, isCurrent: false, status: status, now: seen)
        }
        #expect(stale(.offline) == "Last known position · just now · Flight data unavailable")
        #expect(stale(.quiet) == "Last known position · just now · Quiet hours")
        #expect(stale(.needsHome) == "Last known position · just now · Set your home location")
    }

    @Test func staleStatsSayTheyAreFromTheLastSighting() {
        let stat = Formatting.Stat(value: "900 ft", label: "Above you", spoken: "900 feet above you")
        #expect(stat.spokenLabel(isStale: false) == "900 feet above you")
        #expect(stat.spokenLabel(isStale: true) == "900 feet above you, at last known position")
    }

    @Test func emptyStatesKeepNoPlanesApartFromUnavailableData() {
        #expect(Formatting.emptyState(.loading).title == "Looking for nearby flights…")
        #expect(Formatting.emptyState(.loading).detail == nil)
        #expect(Formatting.emptyState(.idle).title == "No planes nearby")
        #expect(Formatting.emptyState(.idle).detail == "Flights will appear here when detected.")
        #expect(Formatting.emptyState(.offline).title == "Flight data unavailable")
        #expect(Formatting.emptyState(.quiet).title == "Quiet hours")
        #expect(Formatting.emptyState(.needsHome).title == "Set your home location")
    }
}
