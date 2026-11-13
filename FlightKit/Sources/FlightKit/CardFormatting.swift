import Foundation

/// Copy for the flight card, read from existing fields. A missing value shows as missing, never as a guess.
extension Formatting {
    /// One glanceable number: the value on top, the label under it, and a full sentence for VoiceOver.
    public struct Stat: Sendable, Equatable {
        public let value: String
        public let label: String
        public let spoken: String

        /// A stale number read aloud on its own would sound current.
        public func spokenLabel(isStale: Bool) -> String {
            isStale ? "\(spoken), at last known position" : spoken
        }
    }

    /// "Nearby now" only for a plane on the latest successful check. Otherwise the numbers below are a
    /// last known position, said up front, with why nothing is live when it isn't just an empty sky.
    public static func freshness(seenAt: Date, isCurrent: Bool, status: FlightTracker.Status, now: Date) -> String {
        if isCurrent { return "Nearby now" }
        let seen = "Last known position · \(ago(seenAt, now: now))"
        return status == .idle ? seen : "\(seen) · \(emptyState(status).title)"
    }

    static let missingValue = "—"

    /// "Chicago → Cleveland": cities read faster than codes; the codes get their own line.
    public static func routeHeadline(_ route: Route) -> String {
        "\(route.origin.city ?? route.origin.name) → \(route.destination.city ?? route.destination.name)"
    }

    public static func routeCodes(_ route: Route) -> String {
        "\(route.origin.iata ?? route.origin.icao) → \(route.destination.iata ?? route.destination.icao)"
    }

    /// "EWR → CLE · 350 mi to go · about halfway". A stale card passes no position: a frozen countdown
    /// would read as live.
    public static func routeCodes(_ route: Route, position: Coordinate?) -> String {
        let progress = position.flatMap { tripProgress(route, position: $0) }
        let parts = progress.map { [$0.miles + " mi to go", $0.stage].compactMap(\.self) } ?? []
        return ([routeCodes(route)] + parts).joined(separator: " · ")
    }

    /// "EWR to CLE, 350 miles to go, about halfway": VoiceOver reads "→" as "right arrow" and "mi" as letters.
    public static func spokenRouteCodes(_ route: Route, position: Coordinate?) -> String {
        let codes = "\(route.origin.iata ?? route.origin.icao) to \(route.destination.iata ?? route.destination.icao)"
        let progress = position.flatMap { tripProgress(route, position: $0) }
        let parts = progress.map { [$0.miles + " miles to go", $0.stage].compactMap(\.self) } ?? []
        return ([codes] + parts).joined(separator: ", ")
    }

    /// Below this the plane is all but down, and a countdown in the last miles would only twitch.
    static let tripProgressFloorMiles = 25.0

    /// Straight-line miles to the destination, in tens so the number holds still between checks. Progress is
    /// along the great circle; the flown path is a little longer, which "about" covers.
    static func tripProgress(_ route: Route, position: Coordinate) -> (miles: String, stage: String?)? {
        let (origin, destination) = (route.origin.coordinate, route.destination.coordinate)
        let remaining = Geo.distanceMiles(position, destination)
        let total = Geo.distanceNauticalMiles(origin, destination)
        guard remaining >= tripProgressFloorMiles, total > 0 else { return nil }
        let tens = Int((remaining / 10).rounded()) * 10
        let miles = tens.formatted(.number.grouping(.automatic).locale(usEnglish))
        let fraction = Geo.alongTrackNauticalMiles(point: position, from: origin, to: destination) / total
        switch fraction {
        case 0.4...0.6: return (miles, "about halfway")
        case 0.85...: return (miles, "nearly there")
        default: return (miles, nil)
        }
    }

    /// "Southwest Airlines · WN4479". The full name stays; a short-name table would be one more thing to drift.
    public static func flightIdentity(callsign: String?, registration: String?, routeAirline: String?) -> String {
        flightName(callsign: callsign, registration: registration, routeAirline: routeAirline, separator: " · ")
    }

    /// Height is above home's ground, not sea level, so "Above you" is accurate. Speed is ground speed.
    /// On a stale card "Above you" would read as current, so it becomes the height at that sighting.
    public static func stats(_ plane: NearbyPlane, isStale: Bool) -> [Stat] {
        let feet = plane.heightAboveHomeFeet.formatted(.number.grouping(.automatic).locale(usEnglish))
        let miles = plane.distanceMiles.formatted(.number.precision(.fractionLength(1)).locale(usEnglish))
        let speed = plane.aircraft.groundSpeedKnots.flatMap(mph(knots:)).map {
            Stat(value: "\($0) mph", label: "Speed", spoken: "\($0) miles per hour")
        }
        return [
            Stat(value: "\(feet) ft", label: isStale ? "Height above you" : "Above you",
                 spoken: "\(feet) feet above you"),
            Stat(value: "\(miles) mi", label: "Distance", spoken: "\(miles) miles away"),
            speed ?? Stat(value: missingValue, label: "Speed", spoken: "Speed unavailable"),
        ]
    }

    /// When the flight identity is already the registration (no callsign, or a light aircraft broadcasting
    /// its tail number), it isn't said twice.
    public static func aircraftLine(_ aircraft: Aircraft) -> String? {
        let registration = aircraft.registration.flatMap {
            flightLabel(callsign: aircraft.callsign, registration: $0) == $0 ? nil : $0
        }
        let parts = [aircraft.typeDescription ?? aircraft.typeCode, registration].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Calendar years, matching how the feed reports the build year. No age under one year, so never "0 years".
    public static func builtLine(year: Int, currentYear: Int) -> String {
        let age = currentYear - year
        switch age {
        case ..<1: return "Built \(year)"
        case 1: return "Built \(year) · 1 year old"
        default: return "Built \(year) · \(age) years old"
        }
    }

    public static func seatsLine(typeCode: String?) -> String? {
        typeCode.flatMap(Lookups.typicalSeats(forTypeCode:)).map { "~\($0) seats · typical capacity" }
    }

    /// `Phase.classify` falls back to `.passingOver` when it knows nothing, so that case alone isn't shown.
    public static func status(_ phase: FlightPhase, hasRoute: Bool) -> String? {
        phase == .passingOver && !hasRoute ? nil : self.phase(phase)
    }

    /// The card when there's no plane to show. "No planes" and "can't tell" must never look alike.
    public static func emptyState(_ status: FlightTracker.Status) -> (title: String, detail: String?) {
        switch status {
        case .loading: ("Looking for nearby flights…", nil)
        case .idle: ("No planes nearby", "Flights will appear here when detected.")
        case .offline: ("Flight data unavailable", "Can't reach the flight feed. Trying again automatically.")
        case .quiet: ("Quiet hours", "Planes will show again when they end.")
        case .needsHome: ("Set your home location", "Open Settings, then click Save location.")
        }
    }
}
