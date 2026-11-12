import Foundation
import Testing
@testable import FlightKit

/// A point `miles` from CLE on a true bearing; flat-earth is plenty for a few miles.
func nearCLE(miles: Double, bearing: Double) -> Coordinate {
    let airport = RunwayFlowWatch.airport
    let radians = bearing * .pi / 180
    let north = miles * cos(radians) / Geo.milesPerDegreeLatitude
    let east = miles * sin(radians) / (Geo.milesPerDegreeLatitude * cos(airport.latitude * .pi / 180))
    return Coordinate(latitude: airport.latitude + north, longitude: airport.longitude + east)
}

@Suite struct RunwayFlowTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    func plane(
        _ hex: String, at position: Coordinate, track: Double?, rate: Int?, altitude: Int? = 2_000
    ) -> Aircraft {
        Aircraft(hex: hex, altitudeFeet: altitude, verticalRateFpm: rate, trackDegrees: track, coordinate: position)
    }

    /// Northeast of the field, heading southwest and coming down: lining up for runway 24.
    func landing24(_ hex: String) -> Aircraft {
        plane(hex, at: nearCLE(miles: 3, bearing: 52), track: 232, rate: -700)
    }

    func flow(after aircraft: [Aircraft]) -> RunwayFlow? {
        var watch = RunwayFlowWatch()
        watch.record(aircraft, at: start)
        return watch.flow(now: start)
    }

    @Test func lowPlanesDescendingSouthwestMeanLandingOn24() {
        #expect(flow(after: [landing24("a"), landing24("b")]) == .runway24)
    }

    /// Planes land and take off into the wind, so a departure climbing out says the same as an arrival.
    @Test func departuresAndArrivalsBothCount() {
        let arriving = plane("a", at: nearCLE(miles: 3, bearing: 232), track: 52, rate: -700)
        let departing = plane("b", at: nearCLE(miles: 2, bearing: 52), track: 52, rate: 1_500)
        #expect(flow(after: [arriving, departing]) == .runway6)
    }

    @Test func onePlaneIsNotEnoughToCallIt() {
        #expect(flow(after: [landing24("a")]) == nil)
    }

    @Test func splitTrafficIsNotCalled() {
        let other = plane("c", at: nearCLE(miles: 3, bearing: 232), track: 52, rate: -700)
        #expect(flow(after: [landing24("a"), landing24("b"), other]) == nil)
    }

    @Test func trafficThatSaysNothingAboutTheRunwaysIsIgnored() {
        let ignored = [
            plane("high", at: nearCLE(miles: 3, bearing: 52), track: 232, rate: -700, altitude: 9_000),
            plane("far", at: nearCLE(miles: 15, bearing: 52), track: 232, rate: -700),
            plane("level", at: nearCLE(miles: 3, bearing: 52), track: 232, rate: 0),
            plane("crossing", at: nearCLE(miles: 3, bearing: 52), track: 140, rate: -700),
            plane("noTrack", at: nearCLE(miles: 3, bearing: 52), track: nil, rate: -700),
            plane("noRate", at: nearCLE(miles: 3, bearing: 52), track: 232, rate: nil),
            plane("onGround", at: nearCLE(miles: 0.5, bearing: 52), track: 232, rate: -700, altitude: nil),
        ]
        for aircraft in ignored {
            #expect(flow(after: [landing24("a"), aircraft]) == nil, "\(aircraft.hex) should not count")
        }
    }

    @Test func aPlaneSeenOnManyChecksCountsOnce() {
        var watch = RunwayFlowWatch()
        for step in 0..<3 { watch.record([landing24("a")], at: start.addingTimeInterval(Double(step) * 5)) }
        #expect(watch.flow(now: start.addingTimeInterval(10)) == nil)
    }

    /// The flow changes with the wind; an hour-old landing says nothing about now.
    @Test func oldPlanesStopCounting() {
        var watch = RunwayFlowWatch()
        watch.record([landing24("a"), landing24("b")], at: start)
        #expect(watch.flow(now: start.addingTimeInterval(RunwayFlowWatch.window)) == .runway24)
        #expect(watch.flow(now: start.addingTimeInterval(RunwayFlowWatch.window + 1)) == nil)
    }

    @Test func homeSouthwestOfTheFieldGetsArrivalsWhenLandingOn6() {
        let home = nearCLE(miles: 2.6, bearing: 255)
        #expect(RunwayFlowWatch.overHome(.runway6, home: home) == .arrivals)
        #expect(RunwayFlowWatch.overHome(.runway24, home: home) == .departures)
    }

    @Test func homeNortheastOfTheFieldIsTheOtherWayAround() {
        let home = nearCLE(miles: 4, bearing: 45)
        #expect(RunwayFlowWatch.overHome(.runway6, home: home) == .departures)
        #expect(RunwayFlowWatch.overHome(.runway24, home: home) == .arrivals)
    }

    /// The runway line must run at the runway's true heading: a home just inside the side limit, far out,
    /// lands on the wrong side of a line that is tilted by even a few degrees.
    @Test func runwayLineFollowsTheTrueHeading() {
        let out = 6 * 1.15078
        let side = 1.35 * 1.15078
        let distance = (out * out + side * side).squareRoot()
        let bearing = 232 + atan2(side, out) * 180 / .pi
        #expect(RunwayFlowWatch.overHome(.runway6, home: nearCLE(miles: distance, bearing: bearing)) == .arrivals)
    }

    /// Well off the runway line, neither arrivals nor departures pass over, so the card doesn't claim either.
    @Test func homeOffTheRunwayLineGetsNeither() {
        let home = nearCLE(miles: 8, bearing: 160)
        #expect(RunwayFlowWatch.overHome(.runway6, home: home) == nil)
        #expect(RunwayFlowWatch.overHome(.runway24, home: home) == nil)
    }

    /// Arrivals on a downwind leg fly the opposite way to the landing runway, a few miles to its side.
    @Test func planesOffToTheSideOfTheRunwayLineDoNotVote() {
        let downwind = ["d1", "d2"].map {
            plane($0, at: nearCLE(miles: 4.6, bearing: 322), track: 52, rate: -700, altitude: 3_500)
        }
        #expect(flow(after: downwind) == nil)
    }

    /// A departure off 6 that turns back southwest while still climbing isn't lined up for 24.
    @Test func aDepartureTurningBackKeepsItsVote() {
        var watch = RunwayFlowWatch()
        let departing = ["a", "b"].map { plane($0, at: nearCLE(miles: 2, bearing: 52), track: 52, rate: 1_500) }
        watch.record(departing, at: start)
        let turningBack = plane("a", at: nearCLE(miles: 4, bearing: 52), track: 232, rate: 1_200)
        watch.record([turningBack], at: start.addingTimeInterval(30))
        #expect(watch.flow(now: start.addingTimeInterval(30)) == .runway6)
    }

    @Test func threeOfFourAgreeingIsEnough() {
        let other = plane("c", at: nearCLE(miles: 3, bearing: 232), track: 52, rate: -700)
        #expect(flow(after: [landing24("a"), landing24("b"), landing24("d"), other]) == .runway24)
    }

    @Test func expiredVotesAreDropped() {
        var watch = RunwayFlowWatch()
        watch.record([landing24("a")], at: start)
        watch.record([], at: start.addingTimeInterval(RunwayFlowWatch.window + 1))
        #expect(watch == RunwayFlowWatch())
    }

    @Test func homeFarOutAlongTheRunwayLineGetsNeither() {
        #expect(RunwayFlowWatch.overHome(.runway6, home: nearCLE(miles: 13, bearing: 232)) == .arrivals)
        #expect(RunwayFlowWatch.overHome(.runway6, home: nearCLE(miles: 15, bearing: 232)) == nil)
    }

    @Test func runwayLineSaysTheRunwayAndWhatPassesOver() {
        #expect(Formatting.runwayLine(.runway6, overHome: .arrivals) == "CLE landing on runway 6 · arrivals over you")
        #expect(Formatting.runwayLine(.runway24, overHome: .departures)
            == "CLE landing on runway 24 · departures over you")
        #expect(Formatting.runwayLine(.runway24, overHome: nil) == "CLE landing on runway 24")
    }
}
