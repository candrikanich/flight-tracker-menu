import Foundation

/// Where each aircraft in feed range has been, from the app's own checks. No extra data source.
public struct Tracks: Sendable, Equatable {
    /// About 30 minutes of 5-second checks, far longer than a plane stays in the feed's circle.
    public static let maxPoints = 360
    /// A plane out of the feed this long has left; its path isn't worth keeping.
    public static let forgetAfter: TimeInterval = 30 * 60

    /// A plane out of the feed longer than the slowest retry (60 s) flew somewhere the app didn't see.
    public static let maxGap: TimeInterval = 90

    private struct Point: Sendable, Equatable {
        let coordinate: Coordinate
        let time: Date
    }

    private struct Path: Sendable, Equatable {
        var points: [Point]
        /// Last time the plane was in the feed, moved or not: what the gap and forget rules measure from.
        var updated: Date
    }

    private var paths: [String: Path] = [:]

    public init() {}

    /// `through` cuts the path at a moment, so a stale card's path ends where its plane icon is.
    public func path(for hex: String, through time: Date = .distantFuture) -> [Coordinate] {
        (paths[hex]?.points ?? []).prefix { $0.time <= time }.map(\.coordinate)
    }

    mutating func record(_ aircraft: [Aircraft], at time: Date) {
        for plane in aircraft {
            var path = paths[plane.hex].flatMap { time.timeIntervalSince($0.updated) <= Self.maxGap ? $0 : nil }
                ?? Path(points: [], updated: time)
            if path.points.last?.coordinate != plane.coordinate {
                path.points.append(Point(coordinate: plane.coordinate, time: time))
                path.points = Array(path.points.suffix(Self.maxPoints))
            }
            path.updated = time
            paths[plane.hex] = path
        }
    }

    /// `keeping` is the plane the card still shows, so a stale card keeps its path.
    mutating func prune(now: Date, keeping hex: String?) {
        paths = paths.filter { key, path in key == hex || now.timeIntervalSince(path.updated) <= Self.forgetAfter }
    }
}

/// The map tile's view of the area: home, the plane and its path, never tighter than a few miles.
public enum MapFraming {
    public struct Region: Sendable, Equatable {
        public let center: Coordinate
        public let latitudeDelta: Double
        public let longitudeDelta: Double
    }

    public static let minimumSpanMiles = 3.0
    /// Room around the outermost points so the plane symbol isn't cut off at the edge.
    static let padding = 1.3
    /// The whole-trip tile is mostly empty map, so the plane gets more room from the edge there.
    static let routePadding = 1.6

    public static func region(home: Coordinate, plane: Coordinate, path: [Coordinate]) -> Region {
        region(fitting: [home, plane] + path)
    }

    static func region(fitting points: [Coordinate], padding: Double = padding) -> Region {
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        let (south, north) = (latitudes.min()!, latitudes.max()!)
        let (west, east) = (longitudes.min()!, longitudes.max()!)
        let center = Coordinate(latitude: (south + north) / 2, longitude: (west + east) / 2)

        let minimumLatitudeDelta = minimumSpanMiles / Geo.milesPerDegreeLatitude
        let minimumLongitudeDelta = minimumLatitudeDelta / cos(center.latitude * .pi / 180)
        return Region(
            center: center,
            latitudeDelta: min(max((north - south) * padding, minimumLatitudeDelta), 180),
            longitudeDelta: min(max((east - west) * padding, minimumLongitudeDelta), 360)
        )
    }
}
