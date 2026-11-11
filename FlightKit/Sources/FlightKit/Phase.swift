public enum Phase {
    static let climbOrDescentThresholdFpm = 300

    public static func classify(_ plane: Aircraft, route: Route?, homeAirportICAO: String = "KCLE") -> FlightPhase {
        if let route {
            if route.destination.icao == homeAirportICAO { return .arriving }
            if route.origin.icao == homeAirportICAO { return .departing }
            return .passingOver
        }
        guard let altitude = plane.altitudeFeet, altitude < NearbyCriteria.highAltitudeThresholdFeet,
              let rate = plane.verticalRateFpm else { return .passingOver }
        // Without a route, a low descending plane is probably landing at CLE, but it could be Burke Lakefront.
        if rate <= -climbOrDescentThresholdFpm { return .descending }
        if rate >= climbOrDescentThresholdFpm { return .climbing }
        return .passingOver
    }
}
