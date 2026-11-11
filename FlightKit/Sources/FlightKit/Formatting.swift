import Foundation

public enum Formatting {
    static let mphPerKnot = 1.150779

    public static func menuBarText(_ plane: NearbyPlane, route: Route?) -> String {
        "✈︎ " + summary(plane, route: route)
    }

    /// The menu-bar line without the plane symbol, for places that show their own icon.
    public static func summary(_ plane: NearbyPlane, route: Route?) -> String {
        let label = flightLabel(callsign: plane.aircraft.callsign, registration: plane.aircraft.registration)
        let destination = route.map { " → \($0.destination.iata ?? $0.destination.icao)" } ?? ""
        let miles = plane.distanceMiles.formatted(.number.precision(.fractionLength(1)).locale(usEnglish))
        let feet = plane.heightAboveHomeFeet.formatted(.number.grouping(.automatic).locale(usEnglish))
        return "\(label)\(destination) · \(miles) mi · \(feet) ft"
    }

    /// Minute precision on purpose: a counter ticking every second is the kind of motion the app avoids.
    public static func lastSeen(_ date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "Last seen just now"
        case ..<3_600: return "Last seen \(Int(seconds / 60)) min ago"
        default: return "Last seen \(Int(seconds / 3_600)) hr ago"
        }
    }

    /// IATA flight number when the airline is known (`UAL1365` → `UA1365`), else the callsign, else the registration.
    public static func flightLabel(callsign: String?, registration: String?) -> String {
        if let callsign {
            guard let airline = Lookups.airline(forCallsign: callsign) else { return callsign }
            return airline.iata + callsign.dropFirst(3)
        }
        return registration ?? "Unknown aircraft"
    }

    /// nil for values no aircraft can fly, which also keeps the Int conversion from trapping.
    public static func mph(knots: Double) -> Int? {
        Int(exactly: (knots * mphPerKnot).rounded()).flatMap { (0...5_000).contains($0) ? $0 : nil }
    }

    /// Fixed so the menu bar reads the same regardless of system region; the app's copy is English-only.
    private static let usEnglish = Locale(identifier: "en_US")
}
