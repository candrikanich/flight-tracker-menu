import Foundation

/// A day's summary of what passed over, derived from the sky log so each pass counts once.
public struct DailyTally: Sendable, Equatable {
    public let count: Int
    /// Start of the hour with the most passes; nil unless one hour clearly leads with at least two.
    public let busiestHour: Date?
    /// The most common airline; nil unless one clearly leads with at least two passes.
    public let topAirline: String?

    public init(count: Int, busiestHour: Date?, topAirline: String?) {
        self.count = count
        self.busiestHour = busiestHour
        self.topAirline = topAirline
    }

    /// Passes belong to the day they started, matching how the sky log groups them.
    public init(passes: [Pass], on day: Date, calendar: Calendar) {
        let today = passes.filter { calendar.isDate($0.firstSeen, inSameDayAs: day) }
        count = today.count
        busiestHour = Self.clearLeader(today.compactMap { calendar.dateInterval(of: .hour, for: $0.firstSeen)?.start })
        topAirline = Self.clearLeader(today.compactMap(\.airlineName))
    }

    /// Calm by design: a tie or a single occurrence isn't worth calling out.
    private static func clearLeader<Value: Hashable>(_ values: [Value]) -> Value? {
        let ranked = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +).sorted { $0.value > $1.value }
        guard let first = ranked.first, first.value >= 2 else { return nil }
        if ranked.count > 1, ranked[1].value == first.value { return nil }
        return first.key
    }
}

extension Pass {
    /// The callsign lookup comes first because it spells each airline one way, so passes group together.
    var airlineName: String? {
        callsign.flatMap(Lookups.airline(forCallsign:))?.name ?? route?.airlineName
    }
}
