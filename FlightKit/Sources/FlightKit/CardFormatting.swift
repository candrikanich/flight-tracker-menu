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
            isStale ? "\(spoken), when last seen" : spoken
        }
    }

    /// "Nearby now" only for a plane on the latest successful check; otherwise when it was seen and,
    /// if something other than an empty sky is the reason, why nothing is live.
    public static func freshness(seenAt: Date, isCurrent: Bool, status: FlightTracker.Status, now: Date) -> String {
        if isCurrent { return "Nearby now" }
        let seen = lastSeen(seenAt, now: now)
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

    /// "Southwest Airlines · WN4479". The full name stays; a short-name table would be one more thing to drift.
    public static func flightIdentity(callsign: String?, registration: String?, routeAirline: String?) -> String {
        flightName(callsign: callsign, registration: registration, routeAirline: routeAirline, separator: " · ")
    }

    /// Height is above home's ground, not sea level, so "Above you" is accurate. Speed is ground speed.
    public static func stats(_ plane: NearbyPlane) -> [Stat] {
        let feet = plane.heightAboveHomeFeet.formatted(.number.grouping(.automatic).locale(usEnglish))
        let miles = plane.distanceMiles.formatted(.number.precision(.fractionLength(1)).locale(usEnglish))
        let speed = plane.aircraft.groundSpeedKnots.flatMap(mph(knots:)).map {
            Stat(value: "\($0) mph", label: "Speed", spoken: "\($0) miles per hour")
        }
        return [
            Stat(value: "\(feet) ft", label: "Above you", spoken: "\(feet) feet above you"),
            Stat(value: "\(miles) mi", label: "Distance", spoken: "\(miles) miles away"),
            speed ?? Stat(value: missingValue, label: "Speed", spoken: "Speed unavailable"),
        ]
    }

    public static func aircraftLine(_ aircraft: Aircraft) -> String? {
        let parts = [aircraft.typeDescription ?? aircraft.typeCode, aircraft.registration].compactMap(\.self)
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
