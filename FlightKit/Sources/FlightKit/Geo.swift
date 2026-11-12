import Foundation

public enum Geo {
    static let earthRadiusMiles = 3958.8
    static let earthRadiusNauticalMiles = 3440.065
    static let feetPerMile = 5280.0
    static let milesPerDegreeLatitude = earthRadiusMiles * .pi / 180

    public static func distanceMiles(_ a: Coordinate, _ b: Coordinate) -> Double {
        angularDistance(a, b) * earthRadiusMiles
    }

    /// Distance from `point` to the great circle through `from` and `to`.
    public static func crossTrackNauticalMiles(point: Coordinate, from: Coordinate, to: Coordinate) -> Double {
        let delta13 = angularDistance(from, point)
        let theta13 = bearing(from, point)
        let theta12 = bearing(from, to)
        return abs(asin(sin(delta13) * sin(theta13 - theta12))) * earthRadiusNauticalMiles
    }

    /// How far along the path from `from` toward `to` the point closest to `point` lies; negative means behind `from`.
    public static func alongTrackNauticalMiles(point: Coordinate, from: Coordinate, to: Coordinate) -> Double {
        let delta13 = angularDistance(from, point)
        let relativeBearing = bearing(from, point) - bearing(from, to)
        let crossTrack = asin(sin(delta13) * sin(relativeBearing))
        let along = acos(max(-1, min(1, cos(delta13) / cos(crossTrack))))
        return (cos(relativeBearing) < 0 ? -along : along) * earthRadiusNauticalMiles
    }

    public static func distanceNauticalMiles(_ a: Coordinate, _ b: Coordinate) -> Double {
        angularDistance(a, b) * earthRadiusNauticalMiles
    }

    public static func elevationAngleDegrees(heightFeet: Double, horizontalMiles: Double) -> Double {
        atan2(heightFeet, horizontalMiles * feetPerMile) * 180 / .pi
    }

    private static func angularDistance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.latitude.radians, lat2 = b.latitude.radians
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude).radians
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * asin(min(1, sqrt(h)))
    }

    private static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.latitude.radians, lat2 = b.latitude.radians
        let dLon = (b.longitude - a.longitude).radians
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x)
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
}
