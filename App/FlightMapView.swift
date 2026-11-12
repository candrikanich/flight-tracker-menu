import FlightKit
import MapKit
import SwiftUI

/// A glance tile, not a map to explore: fixed framing, no panning, so scrolling the popover never drags it.
/// It draws only what the app saw. A planned origin-to-destination line would cut across a tile a few miles
/// wide and contradict the vectors the plane is actually flying.
struct FlightMapView: View {
    let home: Coordinate
    let aircraft: Aircraft
    /// Positions from the app's own checks while the plane was in feed range.
    let path: [Coordinate]
    let route: Route?

    var body: some View {
        Map(position: .constant(.region(region)), interactionModes: []) {
            if path.count > 1 {
                MapPolyline(coordinates: path.map(\.map)).stroke(.blue, lineWidth: 2.5)
            }
            Annotation("Home", coordinate: home.map, anchor: .center) {
                Image(systemName: "house.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color.gray, in: .circle)
            }
            .annotationTitles(.hidden)
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

    private var region: MKCoordinateRegion {
        let framing = MapFraming.region(home: home, plane: aircraft.coordinate, path: path)
        return MKCoordinateRegion(
            center: framing.center.map,
            span: MKCoordinateSpan(latitudeDelta: framing.latitudeDelta, longitudeDelta: framing.longitudeDelta)
        )
    }

    private var accessibilityText: String {
        let trip = route.map { " on its way from \(Formatting.routeHeadline($0))" } ?? ""
        let seen = path.count > 1 ? ", with the path it flew while nearby" : ""
        return "Map of home and the plane\(trip)\(seen)"
    }
}

private extension Coordinate {
    var map: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
