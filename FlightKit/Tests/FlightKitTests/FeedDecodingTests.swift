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

    /// adsb.fi `dbFlags`: bit 1 is military; bit 8 (LADD, a privacy list) must not count.
    @Test func militaryComesFromTheFirstDbFlagsBit() throws {
        let json = """
        {"aircraft":[
        {"hex":"ae01ce","dbFlags":1,"alt_baro":5000,"lat":41.4,"lon":-81.8},
        {"hex":"a2c990","dbFlags":8,"alt_baro":5000,"lat":41.4,"lon":-81.8},
        {"hex":"a2f1c3","alt_baro":5000,"lat":41.4,"lon":-81.8}
        ]}
        """
        let decoded = try FeedDecoding.aircraft(from: Data(json.utf8))

        #expect(decoded.map(\.isMilitary) == [true, false, false])
    }

    /// The flag only adds a badge, so a malformed value must not hide the plane.
    @Test func malformedDbFlagsKeepsThePlane() throws {
        let json = #"{"aircraft":[{"hex":"ae01ce","dbFlags":"1","alt_baro":5000,"lat":41.4,"lon":-81.8}]}"#
        let decoded = try FeedDecoding.aircraft(from: Data(json.utf8))

        #expect(decoded.map(\.hex) == ["ae01ce"])
        #expect(decoded.first?.isMilitary == false)
    }

    @Test func airlinerDecodesEveryField() throws {
        let united = try #require(aircraft.first { $0.hex == "a2f1c3" })
        #expect(united.callsign == "UAL1365")
        #expect(united.registration == "N27733")
        #expect(united.typeCode == "B737")
        #expect(united.typeDescription == "BOEING 737-700")
        #expect(united.yearBuilt == 1999)
        #expect(united.altitudeFeet == 39_400)
        #expect(united.groundSpeedKnots == 450.1)
        #expect(united.verticalRateFpm == 0)
        #expect(united.squawk == "1234")
        #expect(united.coordinate == Coordinate(latitude: 41.52, longitude: -81.70))
    }

    @Test func headingComesFromTrackAndIsOptional() throws {
        let united = try #require(aircraft.first { $0.hex == "a2f1c3" })
        #expect(united.trackDegrees == 95.2)
        let vehicle = try #require(aircraft.first { $0.hex == "a3a310" })
        #expect(vehicle.trackDegrees == nil)
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

    @Test func absurdAltitudeDropsOnlyThatRecordInsteadOfCrashing() throws {
        let json = """
        {"aircraft":[
          {"hex":"bad1","alt_baro":1e300,"lat":41.4,"lon":-81.8},
          {"hex":"bad2","alt_baro":-99999999999999,"lat":41.4,"lon":-81.8},
          {"hex":"good","alt_baro":3000.4,"lat":41.4,"lon":-81.8}
        ]}
        """
        let decoded = try FeedDecoding.aircraft(from: Data(json.utf8))
        #expect(decoded.map(\.hex) == ["good"])
        #expect(decoded.first?.altitudeFeet == 3_000)
    }

    @Test func geometricAltitudeIsPreferredOverPressureAltitude() throws {
        let json = #"{"aircraft":[{"hex":"geo","alt_baro":2000,"alt_geom":2300,"lat":41.4,"lon":-81.8}]}"#
        #expect(try FeedDecoding.aircraft(from: Data(json.utf8)).first?.altitudeFeet == 2_300)
    }

    @Test func pressureAltitudeIsUsedWhenThereIsNoGeometricAltitude() throws {
        let json = #"{"aircraft":[{"hex":"baro","alt_baro":2000,"lat":41.4,"lon":-81.8}]}"#
        #expect(try FeedDecoding.aircraft(from: Data(json.utf8)).first?.altitudeFeet == 2_000)
    }

    @Test func groundStaysOnTheGroundEvenWithGeometricAltitude() throws {
        let json = #"{"aircraft":[{"hex":"taxi","alt_baro":"ground","alt_geom":800,"lat":41.4,"lon":-81.8}]}"#
        #expect(try FeedDecoding.aircraft(from: Data(json.utf8)).first?.altitudeFeet == nil)
    }

    @Test func absurdGroundSpeedIsDiscarded() throws {
        let json = #"{"aircraft":[{"hex":"fast","alt_baro":3000,"gs":1e300,"lat":41.4,"lon":-81.8}]}"#
        let decoded = try FeedDecoding.aircraft(from: Data(json.utf8))
        #expect(decoded.first?.groundSpeedKnots == nil)
    }

    @Test func malformedJSONThrows() {
        #expect(throws: (any Error).self) {
            try FeedDecoding.aircraft(from: Data("{".utf8))
        }
    }
}
