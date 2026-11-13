import Foundation

/// What the card's map shows: nothing, the neighborhood the plane is crossing, or its whole trip.
public enum MapMode: String, Sendable, Codable, CaseIterable {
    case off, nearby, fullRoute

    /// Before full route, the map was a plain on/off switch, on by default, and showed the neighborhood.
    public init(legacyShowsMap: Bool?) {
        self = legacyShowsMap == false ? .off : .nearby
    }
}

extension MapFraming {
    /// Frames the whole arc, not just the two airports: a long trip bows toward the pole, past both of them.
    /// nil for a route across the date line, such as an overflight bound for Asia: its longitudes wrap, so the
    /// frame would center on the wrong side of the world.
    public static func routeRegion(route: Route, plane: Coordinate) -> Region? {
        let arc = Geo.greatCircle(from: route.origin.coordinate, to: route.destination.coordinate)
        let crossesDateLine = zip(arc, arc.dropFirst()).contains { abs($0.longitude - $1.longitude) > 180 }
        return crossesDateLine ? nil : region(fitting: arc + [plane], padding: routePadding)
    }
}

extension Geo {
    /// Points along the shortest path over the globe, which is what a long flight roughly follows.
    public static func greatCircle(from start: Coordinate, to end: Coordinate, segments: Int = 64) -> [Coordinate] {
        let a = unitVector(start)
        let b = unitVector(end)
        let angle = acos(max(-1, min(1, a.x * b.x + a.y * b.y + a.z * b.z)))
        guard angle > 1e-9 else { return [start, end] }
        return (0...segments).map { step in
            let fraction = Double(step) / Double(segments)
            let weightA = sin((1 - fraction) * angle) / sin(angle)
            let weightB = sin(fraction * angle) / sin(angle)
            let x = weightA * a.x + weightB * b.x
            let y = weightA * a.y + weightB * b.y
            let z = weightA * a.z + weightB * b.z
            return Coordinate(
                latitude: atan2(z, (x * x + y * y).squareRoot()) * 180 / .pi,
                longitude: atan2(y, x) * 180 / .pi
            )
        }
    }

    private static func unitVector(_ point: Coordinate) -> (x: Double, y: Double, z: Double) {
        let latitude = point.latitude * .pi / 180
        let longitude = point.longitude * .pi / 180
        return (cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sin(latitude))
    }
}
