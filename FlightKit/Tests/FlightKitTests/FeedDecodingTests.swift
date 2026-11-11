import Foundation
import Testing
@testable import FlightKit

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct FeedDecodingTests {
    let aircraft: [Aircraft]

    init() throws {
        aircraft = try FeedDecoding.aircraft(from: fixture("adsbfi-cle"))
    }

    @Test func airlinerDecodesEveryField() throws {
        let united = try #require(aircraft.first { $0.hex == "a2f1c3" })
        #expect(united.callsign == "UAL1365")
        #expect(united.registration == "N27733")
        #expect(united.typeCode == "B737")
        #expect(united.typeDescription == "BOEING 737-700")
        #expect(united.yearBuilt == 1999)
        #expect(united.altitudeFeet == 39_000)
        #expect(united.groundSpeedKnots == 450.1)
        #expect(united.verticalRateFpm == 0)
        #expect(united.squawk == "1234")
        #expect(united.coordinate == Coordinate(latitude: 41.52, longitude: -81.70))
    }

    @Test func groundAltitudeDecodesAsNil() throws {
        let jet = try #require(aircraft.first { $0.hex == "a2c990" })
        #expect(jet.altitudeFeet == nil)
    }

    @Test func groundVehicleKeepsItsCategory() throws {
        let vehicle = try #require(aircraft.first { $0.hex == "a3a310" })
        #expect(vehicle.category == "C2")
        #expect(vehicle.typeCode == nil)
    }

    @Test func missingCallsignDecodesAsNil() throws {
        let premier = try #require(aircraft.first { $0.hex == "a006ad" })
        #expect(premier.callsign == nil)
    }

    @Test func recordWithoutPositionIsDropped() {
        #expect(aircraft.count == 4)
        #expect(!aircraft.contains { $0.hex == "abcdef" })
    }

    @Test func malformedJSONThrows() {
        #expect(throws: (any Error).self) {
            try FeedDecoding.aircraft(from: Data("{".utf8))
        }
    }
}
