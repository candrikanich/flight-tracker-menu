import Foundation

/// One plane's trip past home, built from every sighting of it while it stayed in view.
public struct Pass: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public let hex: String
    public let callsign: String?
    public let registration: String?
    public let typeCode: String?
    public let typeDescription: String?
    public let operatorName: String?
    public internal(set) var route: Route?
    /// The phase at the closest approach, which is what the person heard.
    public internal(set) var phase: FlightPhase
    public internal(set) var squawk: String?
    public let firstSeen: Date
    public internal(set) var lastSeen: Date
    public internal(set) var closestMiles: Double
    public internal(set) var lowestHeightFeet: Int

    init(_ sighting: FlightTracker.Sighting) {
        let aircraft = sighting.plane.aircraft
        id = UUID()
        hex = aircraft.hex
        callsign = aircraft.callsign
        registration = aircraft.registration
        typeCode = aircraft.typeCode
        typeDescription = aircraft.typeDescription
        operatorName = aircraft.operatorName
        route = sighting.route
        phase = sighting.phase
        squawk = aircraft.squawk
        firstSeen = sighting.seenAt
        lastSeen = sighting.seenAt
        closestMiles = sighting.plane.distanceMiles
        lowestHeightFeet = sighting.plane.heightAboveHomeFeet
    }

    mutating func absorb(_ sighting: FlightTracker.Sighting) {
        lastSeen = sighting.seenAt
        route = route ?? sighting.route
        squawk = sighting.plane.aircraft.squawk ?? squawk
        lowestHeightFeet = min(lowestHeightFeet, sighting.plane.heightAboveHomeFeet)
        if sighting.plane.distanceMiles < closestMiles {
            closestMiles = sighting.plane.distanceMiles
            phase = sighting.phase
        }
    }
}

/// History of what passed over, oldest first. Kept on this Mac only.
public struct SkyLog: Sendable, Equatable, Codable {
    public static let retention: TimeInterval = 30 * 86_400

    public private(set) var passes: [Pass] = []

    public init() {}

    public struct Day: Sendable, Equatable {
        public let day: Date
        /// Newest first.
        public let passes: [Pass]
    }

    /// `startsNewPass` comes from the tracker, which watches every plane in range. The log only sees the
    /// closest one, so it can't tell on its own whether a plane briefly out-ranked by another ever left.
    public mutating func record(_ sighting: FlightTracker.Sighting, startsNewPass: Bool) {
        let hex = sighting.plane.aircraft.hex
        if !startsNewPass, let ongoing = passes.lastIndex(where: { $0.hex == hex }) {
            passes[ongoing].absorb(sighting)
        } else {
            passes.append(Pass(sighting))
        }
        prune(now: sighting.seenAt)
    }

    public mutating func prune(now: Date) {
        let cutoff = now - Self.retention
        passes.removeAll { $0.lastSeen < cutoff }
    }

    public func days(calendar: Calendar) -> [Day] {
        Dictionary(grouping: passes) { calendar.startOfDay(for: $0.firstSeen) }
            .map { Day(day: $0.key, passes: $0.value.sorted { $0.firstSeen > $1.firstSeen }) }
            .sorted { $0.day > $1.day }
    }
}
