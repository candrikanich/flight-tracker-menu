import Testing
@testable import FlightKit

@Suite struct PhaseTests {
    @Test func routeIntoClevelandIsArriving() {
        #expect(Phase.classify(plane(verticalRateFpm: 800), route: dfwToCle) == .arriving)
    }

    @Test func routeOutOfClevelandIsDeparting() {
        #expect(Phase.classify(plane(verticalRateFpm: -800), route: cleToEwr) == .departing)
    }

    @Test func routeNotTouchingClevelandIsPassingOver() {
        #expect(Phase.classify(plane(altitudeFeet: 4_000, verticalRateFpm: -800), route: snaToEwr) == .passingOver)
    }

    @Test func descendingLowPlaneWithoutRouteIsOnlyDescending() {
        #expect(Phase.classify(plane(verticalRateFpm: -300), route: nil) == .descending)
    }

    @Test func climbingLowPlaneWithoutRouteIsOnlyClimbing() {
        #expect(Phase.classify(plane(verticalRateFpm: 300), route: nil) == .climbing)
    }

    @Test func levelLowPlaneWithoutRouteIsPassingOver() {
        #expect(Phase.classify(plane(verticalRateFpm: 299), route: nil) == .passingOver)
        #expect(Phase.classify(plane(verticalRateFpm: nil), route: nil) == .passingOver)
    }

    @Test func highPlaneWithoutRouteIsPassingOverEvenWhenDescending() {
        #expect(Phase.classify(plane(altitudeFeet: 12_000, verticalRateFpm: -1_500), route: nil) == .passingOver)
    }
}
