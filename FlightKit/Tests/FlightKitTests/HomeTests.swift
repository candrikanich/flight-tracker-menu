import Foundation
import Testing
@testable import FlightKit

@Suite struct HomeTests {
    @Test func homeSavedBeforeAddressesExistedStillLoads() throws {
        let saved = Data(#"{"coordinate":{"latitude":41.39,"longitude":-81.92},"groundElevationFeet":790}"#.utf8)

        let home = try JSONDecoder().decode(Home.self, from: saved)

        #expect(home.coordinate == Coordinate(latitude: 41.39, longitude: -81.92))
        #expect(home.groundElevationFeet == 790)
        #expect(home.address == nil)
    }

    @Test func homeKeepsItsAddressThroughSaving() throws {
        let home = Home(
            coordinate: Coordinate(latitude: 41.39, longitude: -81.92),
            groundElevationFeet: 790,
            address: "1 Main St, Olmsted Falls, OH"
        )

        let reloaded = try JSONDecoder().decode(Home.self, from: JSONEncoder().encode(home))

        #expect(reloaded == home)
    }
}
