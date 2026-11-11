import Testing
@testable import FlightKit

let cle = Coordinate(latitude: 41.4117, longitude: -81.8498)
private let den = Coordinate(latitude: 39.8617, longitude: -104.6731)
private let sna = Coordinate(latitude: 33.6757, longitude: -117.868)
private let ewr = Coordinate(latitude: 40.6925, longitude: -74.1687)
private let dfw = Coordinate(latitude: 32.8968, longitude: -97.038)
private let lax = Coordinate(latitude: 33.9425, longitude: -118.408)
private let sfo = Coordinate(latitude: 37.619, longitude: -122.375)

@Suite struct GeoTests {
    @Test func distanceClevelandToDenver() {
        #expect(abs(Geo.distanceMiles(cle, den) - 1_199) <= 5)
    }

    @Test func distanceToSelfIsZero() {
        #expect(Geo.distanceMiles(cle, cle) == 0)
    }

    @Test func crossTrackSantaAnaNewarkIsNearCleveland() {
        #expect(abs(Geo.crossTrackNauticalMiles(point: cle, from: sna, to: ewr) - 41) <= 2)
    }

    @Test func crossTrackDallasNewarkIsFarFromCleveland() {
        #expect(abs(Geo.crossTrackNauticalMiles(point: cle, from: dfw, to: ewr) - 150) <= 3)
    }

    @Test func crossTrackWestCoastRouteIsVeryFar() {
        #expect(Geo.crossTrackNauticalMiles(point: cle, from: lax, to: sfo) > 1_000)
    }

    @Test func elevationAngleDirectlyOverheadIs90() {
        #expect(Geo.elevationAngleDegrees(heightFeet: 35_000, horizontalMiles: 0) == 90)
    }

    @Test func elevationAngleOneMileUpOneMileOverIs45() {
        #expect(abs(Geo.elevationAngleDegrees(heightFeet: 5_280, horizontalMiles: 1) - 45) <= 0.01)
    }
}
