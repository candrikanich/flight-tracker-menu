import Foundation
import Testing
@testable import FlightKit

/// The autopilot's selected altitude, said only while the plane is actually heading for it.
@Suite struct AltitudeTargetTests {
    func aircraft(altitude: Int?, rate: Int?, target: Int?) -> Aircraft {
        Aircraft(hex: "abc123", altitudeFeet: altitude, verticalRateFpm: rate, targetAltitudeFeet: target,
                 coordinate: Coordinate(latitude: 41.45, longitude: -81.80))
    }

    @Test func aRouteKeepsItsPhaseAndAddsTheTarget() {
        let plane = aircraft(altitude: 12_000, rate: -1_500, target: 6_000)
        #expect(Formatting.status(.arriving, hasRoute: true, aircraft: plane)
            == "Arriving CLE · descending to 6,000 ft")
    }

    @Test func withoutARouteTheTargetReplacesTheBareVerb() {
        let plane = aircraft(altitude: 8_000, rate: 2_000, target: 33_000)
        #expect(Formatting.status(.climbing, hasRoute: false, aircraft: plane) == "Climbing to 33,000 ft")
    }

    /// High planes without a route fall back to "passing over", which isn't shown, but the climb is real.
    @Test func aHighClimbWithoutARouteStillSaysWhereItIsGoing() {
        let plane = aircraft(altitude: 25_000, rate: 1_500, target: 33_000)
        #expect(Formatting.status(.passingOver, hasRoute: false, aircraft: plane) == "Climbing to 33,000 ft")
    }

    /// Pilots preset the next altitude while still level; that isn't where the plane is going yet.
    @Test func aLevelPlaneSaysNothingAboutItsPreset() {
        let plane = aircraft(altitude: 34_000, rate: 0, target: 28_000)
        #expect(Formatting.status(.passingOver, hasRoute: true, aircraft: plane) == "Passing over")
        #expect(Formatting.status(.passingOver, hasRoute: false, aircraft: plane) == nil)
    }

    @Test func aTargetBehindTheMotionIsIgnored() {
        let plane = aircraft(altitude: 12_000, rate: 1_500, target: 5_000)
        #expect(Formatting.status(.departing, hasRoute: true, aircraft: plane) == "Departing CLE")
    }

    /// Within a thousand feet the plane is leveling off already, and GPS against pressure altitude differs by
    /// a few hundred feet anyway.
    @Test func aTargetAlmostReachedIsNotWorthSaying() {
        let plane = aircraft(altitude: 32_300, rate: 800, target: 33_000)
        #expect(Formatting.status(.departing, hasRoute: true, aircraft: plane) == "Departing CLE")
    }

    /// Flight levels are set against standard pressure, which can sit 1,500 ft from GPS height at cruise.
    @Test func aFlightLevelIsComparedWithPressureAltitude() {
        let almostLevelInWinter = Aircraft(
            hex: "abc123", altitudeFeet: 33_300, pressureAltitudeFeet: 34_600, verticalRateFpm: 1_200,
            targetAltitudeFeet: 35_000, coordinate: Coordinate(latitude: 41.45, longitude: -81.80))
        let climbingInSummer = Aircraft(
            hex: "abc123", altitudeFeet: 35_100, pressureAltitudeFeet: 32_900, verticalRateFpm: 1_500,
            targetAltitudeFeet: 34_000, coordinate: Coordinate(latitude: 41.45, longitude: -81.80))
        #expect(Formatting.status(.departing, hasRoute: true, aircraft: almostLevelInWinter) == "Departing CLE")
        #expect(Formatting.status(.departing, hasRoute: true, aircraft: climbingInSummer)
            == "Departing CLE · climbing to 34,000 ft")
    }

    /// Below 18,000 ft the altimeter is set to local pressure, so the target is close to true height.
    @Test func aLowTargetIsComparedWithGPSHeight() {
        let plane = Aircraft(
            hex: "abc123", altitudeFeet: 4_000, pressureAltitudeFeet: 3_200, verticalRateFpm: -800,
            targetAltitudeFeet: 3_000, coordinate: Coordinate(latitude: 41.45, longitude: -81.80))
        #expect(Formatting.status(.arriving, hasRoute: true, aircraft: plane)
            == "Arriving CLE · descending to 3,000 ft")
    }

    @Test func noRateOrNoTargetMeansNoTarget() {
        let noRate = aircraft(altitude: 12_000, rate: nil, target: 6_000)
        let noTarget = aircraft(altitude: 12_000, rate: -1_500, target: nil)
        #expect(Formatting.status(.arriving, hasRoute: true, aircraft: noRate) == "Arriving CLE")
        #expect(Formatting.status(.arriving, hasRoute: true, aircraft: noTarget) == "Arriving CLE")
    }

    /// A stale card passes no aircraft: "descending to" from minutes ago would read as live.
    @Test func aStaleCardKeepsOnlyThePhase() {
        #expect(Formatting.status(.arriving, hasRoute: true, aircraft: nil) == "Arriving CLE")
        #expect(Formatting.status(.descending, hasRoute: false, aircraft: nil) == "Descending")
    }

    @Test func voiceOverHearsFeetNotFt() {
        let plane = aircraft(altitude: 12_000, rate: -1_500, target: 6_000)
        #expect(Formatting.spokenStatus(.arriving, hasRoute: true, aircraft: plane)
            == "Arriving CLE, descending to 6,000 feet")
        #expect(Formatting.spokenStatus(.passingOver, hasRoute: false, aircraft: nil) == nil)
    }
}
