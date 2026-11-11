import Foundation

public struct NearbyCriteria: Sendable, Equatable, Codable {
    public static let highAltitudeThresholdFeet = 10_000
    /// Below this the plane is on or just off a runway, or the altitude is noise, not something flying over.
    public static let minHeightAboveHomeFeet = 200

    public var filter: TrafficFilter
    public var radiusMiles: Double
    public var minElevationAngleDegrees: Double

    public init(filter: TrafficFilter = .airport, radiusMiles: Double = 1.5, minElevationAngleDegrees: Double = 40) {
        self.filter = filter
        self.radiusMiles = radiusMiles
        self.minElevationAngleDegrees = minElevationAngleDegrees
    }
}

public struct NearbyPlane: Sendable, Equatable {
    public let aircraft: Aircraft
    public let heightAboveHomeFeet: Int
    public let distanceMiles: Double

    public init(aircraft: Aircraft, heightAboveHomeFeet: Int, distanceMiles: Double) {
        self.aircraft = aircraft
        self.heightAboveHomeFeet = heightAboveHomeFeet
        self.distanceMiles = distanceMiles
    }
}

public enum Nearby {
    public static func closest(in aircraft: [Aircraft], home: Home, criteria: NearbyCriteria) -> NearbyPlane? {
        qualifying(in: aircraft, home: home, criteria: criteria).min { $0.distanceMiles < $1.distanceMiles }
    }

    public static func qualifying(in aircraft: [Aircraft], home: Home, criteria: NearbyCriteria) -> [NearbyPlane] {
        aircraft.compactMap { qualifies($0, home: home, criteria: criteria) }
    }

    public static func qualifies(_ aircraft: Aircraft, home: Home, criteria: NearbyCriteria) -> NearbyPlane? {
        guard let altitude = aircraft.altitudeFeet, aircraft.category?.hasPrefix("C") != true else { return nil }

        let height = Int((Double(altitude) - home.groundElevationFeet).rounded())
        guard height >= NearbyCriteria.minHeightAboveHomeFeet else { return nil }
        let distance = Geo.distanceMiles(home.coordinate, aircraft.coordinate)
        let isHigh = height >= NearbyCriteria.highAltitudeThresholdFeet

        switch (criteria.filter, isHigh) {
        case (.airport, true), (.passingOver, false): return nil
        default: break
        }

        let inView = isHigh
            ? Geo.elevationAngleDegrees(heightFeet: Double(height), horizontalMiles: distance) >= criteria.minElevationAngleDegrees
            : distance <= criteria.radiusMiles
        return inView ? NearbyPlane(aircraft: aircraft, heightAboveHomeFeet: height, distanceMiles: distance) : nil
    }
}
