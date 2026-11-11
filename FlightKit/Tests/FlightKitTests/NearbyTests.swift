import Testing
@testable import FlightKit

@Suite struct NearbyTests {
    let airportOnly = NearbyCriteria(filter: .airport)
    let passingOnly = NearbyCriteria(filter: .passingOver)
    let everything = NearbyCriteria(filter: .all)

    @Test func lowPlaneInsideRadiusQualifies() throws {
        let result = try #require(Nearby.qualifies(plane(milesNorth: 1.4999), home: homeAtSeaLevel, criteria: airportOnly))
        #expect(abs(result.distanceMiles - 1.4999) < 0.001)
    }

    @Test func lowPlaneJustOutsideRadiusDoesNotQualify() {
        #expect(Nearby.qualifies(plane(milesNorth: 1.51), home: homeAtSeaLevel, criteria: airportOnly) == nil)
    }

    @Test func heightIsMeasuredAboveTheHouse() throws {
        let home = Home(coordinate: homeAtSeaLevel.coordinate, groundElevationFeet: 781.6)
        let result = try #require(Nearby.qualifies(plane(altitudeFeet: 2_900, of: home), home: home, criteria: airportOnly))
        #expect(result.heightAboveHomeFeet == 2_118)
    }

    @Test func cruisingPlaneQualifiesAtFortyDegrees() {
        let high = plane(altitudeFeet: 35_000, milesNorth: 7.5)
        #expect(Nearby.qualifies(high, home: homeAtSeaLevel, criteria: passingOnly) != nil)
    }

    @Test func cruisingPlaneTooCloseToHorizonDoesNotQualify() {
        let high = plane(altitudeFeet: 35_000, milesNorth: 9)
        #expect(Nearby.qualifies(high, home: homeAtSeaLevel, criteria: passingOnly) == nil)
    }

    @Test func airportFilterExcludesHighTraffic() {
        let high = plane(altitudeFeet: 35_000, milesNorth: 0.1)
        #expect(Nearby.qualifies(high, home: homeAtSeaLevel, criteria: airportOnly) == nil)
    }

    @Test func passingOverFilterExcludesLowTraffic() {
        #expect(Nearby.qualifies(plane(), home: homeAtSeaLevel, criteria: passingOnly) == nil)
    }

    @Test func allFilterKeepsBoth() {
        #expect(Nearby.qualifies(plane(), home: homeAtSeaLevel, criteria: everything) != nil)
        #expect(Nearby.qualifies(plane(altitudeFeet: 35_000, milesNorth: 2), home: homeAtSeaLevel, criteria: everything) != nil)
    }

    @Test func planeOnTheGroundNeverQualifies() {
        #expect(Nearby.qualifies(plane(altitudeFeet: nil, milesNorth: 0.1), home: homeAtSeaLevel, criteria: everything) == nil)
    }

    @Test func groundVehicleNeverQualifies() {
        let vehicle = plane(altitudeFeet: 1_000, category: "C2", milesNorth: 0.1)
        #expect(Nearby.qualifies(vehicle, home: homeAtSeaLevel, criteria: everything) == nil)
    }

    @Test func planeLessThanTwoHundredFeetAboveTheHouseDoesNotQualify() {
        #expect(Nearby.qualifies(plane(altitudeFeet: 199, milesNorth: 0.2), home: homeAtSeaLevel, criteria: everything) == nil)
        #expect(Nearby.qualifies(plane(altitudeFeet: 200, milesNorth: 0.2), home: homeAtSeaLevel, criteria: everything) != nil)
    }

    @Test func qualifyingListsEveryPlaneInView() {
        let planes = [plane(hex: "a", milesNorth: 0.3), plane(hex: "b", milesNorth: 1.0), plane(hex: "c", milesNorth: 3.0)]
        #expect(Nearby.qualifying(in: planes, home: homeAtSeaLevel, criteria: airportOnly).map(\.aircraft.hex) == ["a", "b"])
    }

    @Test func closestPicksSmallestHorizontalDistance() {
        let far = plane(hex: "far", milesNorth: 1.2)
        let near = plane(hex: "near", milesNorth: 0.3)
        let outside = plane(hex: "out", category: "C1", milesNorth: 0.1)
        #expect(Nearby.closest(in: [far, outside, near], home: homeAtSeaLevel, criteria: airportOnly)?.aircraft.hex == "near")
    }

    @Test func closestIsNilWhenNothingQualifies() {
        #expect(Nearby.closest(in: [plane(milesNorth: 5)], home: homeAtSeaLevel, criteria: airportOnly) == nil)
    }
}
