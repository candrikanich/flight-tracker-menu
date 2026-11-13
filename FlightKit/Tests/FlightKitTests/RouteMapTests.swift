import Foundation
import Testing
@testable import FlightKit

@Suite struct RouteMapTests {
    let cle = Airport(
        iata: "CLE", icao: "KCLE", name: "Cleveland Hopkins", city: "Cleveland",
        coordinate: Coordinate(latitude: 41.4117, longitude: -81.8498)
    )
    let lhr = Airport(
        iata: "LHR", icao: "EGLL", name: "Heathrow", city: "London",
        coordinate: Coordinate(latitude: 51.4700, longitude: -0.4543)
    )
    let lax = Airport(
        iata: "LAX", icao: "KLAX", name: "Los Angeles", city: "Los Angeles",
        coordinate: Coordinate(latitude: 33.9416, longitude: -118.4085)
    )

    func isNear(_ a: Coordinate?, _ b: Coordinate) -> Bool {
        guard let a else { return false }
        return abs(a.latitude - b.latitude) < 1e-6 && abs(a.longitude - b.longitude) < 1e-6
    }

    func contains(_ region: MapFraming.Region, _ point: Coordinate) -> Bool {
        abs(point.latitude - region.center.latitude) <= region.latitudeDelta / 2
            && abs(point.longitude - region.center.longitude) <= region.longitudeDelta / 2
    }

    /// Anyone who had the map on keeps the map they know; off stays off.
    @Test func theOldMapSwitchCarriesOver() {
        #expect(MapMode(legacyShowsMap: nil) == .nearby)
        #expect(MapMode(legacyShowsMap: true) == .nearby)
        #expect(MapMode(legacyShowsMap: false) == .off)
    }

    @Test func greatCircleRunsFromOriginToDestination() {
        let line = Geo.greatCircle(from: cle.coordinate, to: lhr.coordinate)
        #expect(isNear(line.first, cle.coordinate))
        #expect(isNear(line.last, lhr.coordinate))
    }

    /// The shortest way to London arcs up past both airports' latitudes, toward Newfoundland.
    @Test func greatCircleBowsTowardThePole() {
        let line = Geo.greatCircle(from: cle.coordinate, to: lhr.coordinate)
        #expect((line.map(\.latitude).max() ?? 0) > 53)
    }

    @Test func fullRouteFramesBothAirportsThePlaneAndTheArc() throws {
        let plane = Coordinate(latitude: 41.45, longitude: -81.95)
        let route = Route(airlineName: nil, origin: cle, destination: lhr)
        let region = try #require(MapFraming.routeRegion(route: route, plane: plane))
        let arc = Geo.greatCircle(from: cle.coordinate, to: lhr.coordinate)
        #expect((arc + [plane]).allSatisfy { contains(region, $0) })
    }

    /// An overflight from Washington to Tokyo crosses the date line; framing it would center the map on the wrong
    /// side of the world, so full route steps back to nearby.
    @Test func aRouteAcrossTheDateLineIsNotFramed() {
        let iad = Airport(
            iata: "IAD", icao: "KIAD", name: "Dulles", city: "Washington",
            coordinate: Coordinate(latitude: 38.9531, longitude: -77.4565)
        )
        let hnd = Airport(
            iata: "HND", icao: "RJTT", name: "Haneda", city: "Tokyo",
            coordinate: Coordinate(latitude: 35.5494, longitude: 139.7798)
        )
        let plane = Coordinate(latitude: 41.5, longitude: -81.9)
        let route = Route(airlineName: nil, origin: iad, destination: hnd)
        #expect(MapFraming.routeRegion(route: route, plane: plane) == nil)
    }

    /// No input may produce a span MapKit rejects.
    @Test func framingNeverExceedsTheWholeGlobe() {
        let region = MapFraming.region(fitting: [
            Coordinate(latitude: -85, longitude: -179), Coordinate(latitude: 85, longitude: 179),
        ])
        #expect(region.latitudeDelta <= 180)
        #expect(region.longitudeDelta <= 360)
    }

    /// A short hop still gets the nearby minimum span, not a street-level zoom.
    @Test func aShortHopKeepsTheMinimumSpan() {
        let route = Route(airlineName: nil, origin: cle, destination: cle)
        let region = MapFraming.routeRegion(route: route, plane: cle.coordinate)
        #expect((region?.latitudeDelta ?? 0) >= MapFraming.minimumSpanMiles / Geo.milesPerDegreeLatitude)
    }

    /// A plane blown off the line still has to be on the map.
    @Test func fullRouteFramesAPlaneOffTheLine() throws {
        let plane = Coordinate(latitude: 45.0, longitude: -100.0)
        let route = Route(airlineName: nil, origin: cle, destination: lax)
        let region = try #require(MapFraming.routeRegion(route: route, plane: plane))
        #expect(contains(region, plane))
        #expect(contains(region, lax.coordinate))
    }

    /// The plane marker is the point of the tile, so it never sits against the edge.
    @Test func fullRouteLeavesRoomAroundThePlane() throws {
        let plane = Coordinate(latitude: 45.0, longitude: -100.0)
        let route = Route(airlineName: nil, origin: cle, destination: lax)
        let region = try #require(MapFraming.routeRegion(route: route, plane: plane))
        let northEdge = region.center.latitude + region.latitudeDelta / 2
        #expect((northEdge - plane.latitude) / region.latitudeDelta >= 0.18)
    }
}
