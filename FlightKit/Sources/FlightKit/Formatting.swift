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
        "Last seen \(ago(date, now: now))"
    }

    static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3_600: return "\(Int(seconds / 60)) min ago"
        default: return "\(Int(seconds / 3_600)) hr ago"
        }
    }

    /// "United Airlines UA1365": the route source's airline name wins over the callsign-prefix lookup.
    public static func flightTitle(callsign: String?, registration: String?, routeAirline: String?) -> String {
        flightName(callsign: callsign, registration: registration, routeAirline: routeAirline, separator: " ")
    }

    /// One airline-precedence rule for the card and the Sky Log, which differ only in the separator.
    static func flightName(
        callsign: String?, registration: String?, routeAirline: String?, separator: String
    ) -> String {
        let label = flightLabel(callsign: callsign, registration: registration)
        let airline = routeAirline ?? callsign.flatMap(Lookups.airline(forCallsign:))?.name
        return airline.map { "\($0)\(separator)\(label)" } ?? label
    }

    public static func place(_ airport: Airport) -> String {
        "\(airport.city ?? airport.name) (\(airport.iata ?? airport.icao))"
    }

    public static func phase(_ phase: FlightPhase) -> String {
        switch phase {
        case .arriving: "Arriving CLE"
        case .departing: "Departing CLE"
        case .passingOver: "Passing over"
        case .climbing: "Climbing"
        case .descending: "Descending"
        }
    }

    public static func emergency(squawk: String?) -> String? {
        switch squawk {
        case "7700": "Emergency squawk 7700"
        case "7600": "Emergency squawk 7600 radio failure"
        case "7500": "Emergency squawk 7500 hijack"
        default: nil
        }
    }

    public static func rarity(_ rarity: Rarity) -> String {
        switch rarity {
        case .emergency(let squawk): emergency(squawk: squawk) ?? "Emergency squawk \(squawk)"
        case .notableType(let name), .specialOperator(let name): name
        case .military: "Military"
        case .helicopter: "Helicopter"
        case .vintage(let year): "Vintage, built \(year)"
        }
    }

    public static func tallyHeadline(count: Int) -> String {
        "\(count) \(count == 1 ? "plane" : "planes") over you today"
    }

    /// "Busiest around 6 PM · Mostly United Airlines", or nil when nothing stands out.
    public static func tallyDetails(_ tally: DailyTally, calendar: Calendar) -> String? {
        var parts: [String] = []
        if let hour = tally.busiestHour {
            var style = Date.FormatStyle(date: .omitted, time: .omitted).locale(usEnglish)
            style.timeZone = calendar.timeZone
            parts.append("Busiest around \(hour.formatted(style.hour(.defaultDigits(amPM: .abbreviated))))")
        }
        if let airline = tally.topAirline {
            parts.append("Mostly \(airline)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Section title for a day in the sky log.
    public static func dayTitle(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var style = Date.FormatStyle(date: .complete, time: .omitted).locale(usEnglish)
        style.timeZone = calendar.timeZone
        return date.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
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
    static let usEnglish = Locale(identifier: "en_US")
}
