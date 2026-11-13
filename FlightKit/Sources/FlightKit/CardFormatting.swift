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
        let seen = "Last seen \(ago(seenAt, now: now))"
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

    /// The feed capitalizes only the maker ("BOEING 737 MAX 8"). The model after it keeps its own casing, so
    /// designations such as "MAX" and "CRJ-900" stay as they are.
    public static func typeName(_ raw: String) -> String {
        var inMaker = true
        return raw.split(separator: " ", omittingEmptySubsequences: false).map { word in
            guard inMaker, !word.isEmpty, word.allSatisfy({ $0.isLetter && $0.isUppercase }) else {
                inMaker = false
                return String(word)
            }
            return makerWord(String(word))
        }.joined(separator: " ")
    }

    /// Short maker words are initialisms (ATR, BAE, IAI), so they keep their capitals.
    private static func makerWord(_ word: String) -> String {
        if word == "DE" { return "de" }
        if word.count <= 3 { return word }
        if word.hasPrefix("MC") { return "Mc" + word.dropFirst(2).capitalized(with: usEnglish) }
        return word.capitalized(with: usEnglish)
    }

    /// When the flight identity is already the registration (no callsign, or a light aircraft broadcasting
    /// its tail number), it isn't said twice.
    public static func aircraftLine(_ aircraft: Aircraft) -> String? {
        let registration = aircraft.registration.flatMap {
            flightLabel(callsign: aircraft.callsign, registration: $0) == $0 ? nil : $0
        }
        let parts = [aircraft.typeDescription.map(typeName) ?? aircraft.typeCode, registration].compactMap(\.self)
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

    /// "Arriving CLE · descending to 6,000 ft", or "Climbing to 33,000 ft" without a route. A stale card passes
    /// no aircraft, because "descending to" from minutes ago would read as live.
    public static func status(_ phase: FlightPhase, hasRoute: Bool, aircraft: Aircraft?) -> String? {
        statusLine(phase, hasRoute: hasRoute, aircraft: aircraft, separator: " · ", unit: "ft")
    }

    public static func spokenStatus(_ phase: FlightPhase, hasRoute: Bool, aircraft: Aircraft?) -> String? {
        statusLine(phase, hasRoute: hasRoute, aircraft: aircraft, separator: ", ", unit: "feet")
    }

    /// Without a route the phase is only "Climbing" or "Descending" (or nothing), so the target replaces it.
    private static func statusLine(
        _ phase: FlightPhase, hasRoute: Bool, aircraft: Aircraft?, separator: String, unit: String
    ) -> String? {
        let base = status(phase, hasRoute: hasRoute)
        guard let target = aircraft.flatMap(altitudeTarget) else { return base }
        let feet = target.feet.formatted(.number.grouping(.automatic).locale(usEnglish))
        let motion = "\(target.isClimbing ? "climbing" : "descending") to \(feet) \(unit)"
        guard hasRoute, let base else { return motion.prefix(1).uppercased() + motion.dropFirst() }
        return "\(base)\(separator)\(motion)"
    }

    /// Within this the plane is already leveling off.
    static let altitudeTargetMinimumGapFeet = 1_000

    /// From here up, US altitudes are flight levels, set against standard pressure rather than local pressure.
    static let transitionAltitudeFeet = 18_000

    /// Pilots preset the next altitude while still level, so the target counts only while the plane is
    /// actually climbing or descending toward it. A flight level is compared with pressure altitude, which can
    /// sit 1,500 ft from GPS height at cruise; below that the target is set to local pressure, close to GPS.
    static func altitudeTarget(_ aircraft: Aircraft) -> (feet: Int, isClimbing: Bool)? {
        guard let target = aircraft.targetAltitudeFeet, let rate = aircraft.verticalRateFpm,
              abs(rate) >= Phase.climbOrDescentThresholdFpm else { return nil }
        let reference = target >= transitionAltitudeFeet
            ? aircraft.pressureAltitudeFeet ?? aircraft.altitudeFeet
            : aircraft.altitudeFeet
        guard let altitude = reference else { return nil }
        let gap = target - altitude
        guard abs(gap) >= altitudeTargetMinimumGapFeet, (gap > 0) == (rate > 0) else { return nil }
        return (target, rate > 0)
    }

    /// "Registered to Battelle Memorial Institute". Airline flights already lead with the airline. Only
    /// organizations are named: private owners are listed as "LAST FIRST MIDDLE", and a person's name doesn't
    /// belong on the card. A bank holding title as trustee isn't who flies the plane, so it is left out too.
    public static func ownerLine(_ aircraft: Aircraft, routeAirline: String?) -> String? {
        guard let owner = aircraft.operatorName, routeAirline == nil,
              aircraft.callsign.flatMap(Lookups.airline(forCallsign:)) == nil else { return nil }
        let words = Set(owner.uppercased().split { !$0.isLetter }.map(String.init))
        guard !words.contains("TRUSTEE"), !words.isDisjoint(with: organizationWords) else { return nil }
        return "Registered to \(registryName(owner))"
    }

    /// Words that mark an owner as an organization. Missing one only hides the line, the safe way to be wrong.
    private static let organizationWords: Set<String> = [
        "LLC", "INC", "CORP", "CORPORATION", "CO", "COMPANY", "LTD", "LP", "LLP", "PLLC", "PC",
        "INSTITUTE", "UNIVERSITY", "COLLEGE", "ACADEMY", "SCHOOL", "FOUNDATION", "SYSTEM", "HEALTH", "HOSPITAL",
        "CITY", "STATE", "COUNTY", "DEPT", "DEPARTMENT", "ADMINISTRATION", "POLICE", "PATROL", "AIRPORT",
        "AVIATION", "AIRLINES", "AIRWAYS", "AIR", "AERO", "SERVICES", "GROUP", "CLUB", "ASSOCIATION",
        "HOLDINGS", "PARTNERS", "ENTERPRISES", "LEASING", "CHARTER", "FLIGHT", "JETS",
    ]

    /// The FAA registry is all capitals; a name that already has its own casing is kept. Short words are usually
    /// initials (FSI, GLC, LLC), so they stay.
    static func registryName(_ raw: String) -> String {
        guard raw == raw.uppercased() else { return raw }
        return raw.split(separator: " ").enumerated().map { index, word in
            let upper = word.uppercased()
            if index > 0, joiningWords.contains(upper) { return upper.lowercased() }
            if shortWords.contains(upper) || joiningWords.contains(upper) { return upper.capitalized(with: usEnglish) }
            if keptUpper.contains(upper) || upper.count <= 3 || upper.contains(where: \.isNumber)
                || !upper.contains(where: "AEIOUY".contains) {
                return upper
            }
            return upper.capitalized(with: usEnglish)
        }.joined(separator: " ")
    }

    private static let joiningWords: Set<String> = ["OF", "AND", "THE", "FOR", "AT", "BY", "ON", "IN"]
    private static let shortWords: Set<String> = [
        "INC", "CO", "AIR", "JET", "SKY", "ONE", "TWO", "SUN", "BAY", "OAK", "NEW", "BIG", "TOP", "RED", "ACE", "LTD",
    ]
    private static let keptUpper: Set<String> = ["NASA"]

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
