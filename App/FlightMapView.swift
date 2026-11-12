import FlightKit
import MapKit
import SwiftUI

/// A glance tile, not a map to explore: fixed framing, no panning, so scrolling the popover never drags it.
/// Nearby, it draws only what the app saw: a planned origin-to-destination line would cut across a tile a few
/// miles wide and contradict the vectors the plane is actually flying. At full-route scale that line is the
/// point, so it's drawn there, dashed, as the plan rather than the track.
struct FlightMapView: View {
    let home: Coordinate
    let aircraft: Aircraft
    /// Positions from the app's own checks while the plane was in feed range.
    let path: [Coordinate]
    let route: Route?
    let showsFullRoute: Bool

    /// Full route needs a route it can frame; otherwise the tile stays on the neighborhood.
    private var fullRoute: (route: Route, region: MapFraming.Region)? {
        guard showsFullRoute, let route,
              let region = MapFraming.routeRegion(route: route, plane: aircraft.coordinate) else { return nil }
        return (route, region)
    }

    var body: some View {
        Map(position: .constant(.region(region)), interactionModes: []) {
            if let fullRoute = fullRoute?.route {
                MapPolyline(coordinates: Geo.greatCircle(
                    from: fullRoute.origin.coordinate, to: fullRoute.destination.coordinate
                ).map(\.map))
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                Annotation(code(fullRoute.origin), coordinate: fullRoute.origin.coordinate.map, anchor: .center) {
                    airportDot
                }
                Annotation(
                    code(fullRoute.destination), coordinate: fullRoute.destination.coordinate.map, anchor: .center
                ) {
                    airportDot
                }
            }
            if path.count > 1 {
                MapPolyline(coordinates: path.map(\.map)).stroke(.blue, lineWidth: 2.5)
            }
            // At full-route scale home sits right under the plane, so it's left off.
            if fullRoute == nil {
                Annotation("Home", coordinate: home.map, anchor: .center) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.gray, in: .circle)
                }
                .annotationTitles(.hidden)
            }
            Annotation("Plane", coordinate: aircraft.coordinate.map, anchor: .center) {
                planeMarker
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 150)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// The airplane symbol points east, so it turns by heading minus 90°. Without a heading it's a plain dot,
    /// rather than an arrow pointing a way the data doesn't say.
    @ViewBuilder private var planeMarker: some View {
        if let heading = aircraft.trackDegrees {
            Image(systemName: "airplane")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(heading - 90))
        } else {
            Circle().fill(.blue).frame(width: 10, height: 10)
        }
    }

    private var airportDot: some View {
        Circle().fill(Color.gray).frame(width: 7, height: 7)
    }

    private func code(_ airport: Airport) -> String { airport.iata ?? airport.icao }

    private var region: MKCoordinateRegion {
        let framing = fullRoute?.region ?? MapFraming.region(home: home, plane: aircraft.coordinate, path: path)
        return MKCoordinateRegion(
            center: framing.center.map,
            span: MKCoordinateSpan(latitudeDelta: framing.latitudeDelta, longitudeDelta: framing.longitudeDelta)
        )
    }

    private var accessibilityText: String {
        if let fullRoute = fullRoute?.route {
            return "Map of the whole trip from \(Formatting.routeHeadline(fullRoute)), with the plane on it"
        }
        let trip = route.map { " on its way from \(Formatting.routeHeadline($0))" } ?? ""
        let seen = path.count > 1 ? ", with the path it flew while nearby" : ""
        return "Map of home and the plane\(trip)\(seen)"
    }
}

private extension Coordinate {
    var map: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
