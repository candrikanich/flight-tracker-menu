import Foundation
import Observation

@MainActor
@Observable
public final class FlightTracker {
    public enum Status: Equatable, Sendable {
        case idle, quiet, offline
    }

    public struct Sighting: Equatable, Sendable {
        public let plane: NearbyPlane
        public var route: Route?
        public var phase: FlightPhase
        public let seenAt: Date
    }

    /// A plane that has been out of view this long is announced again when it reappears.
    static let reannounceAfter: TimeInterval = 120
    static let backoff: [Duration] = [.seconds(5), .seconds(10), .seconds(20), .seconds(60)]

    public private(set) var current: Sighting?
    public private(set) var lastSeen: Sighting?
    public private(set) var status: Status = .idle
    @ObservationIgnored public var onNewPlane: (@MainActor (Sighting) -> Void)?

    public var nextDelay: Duration {
        Self.backoff[min(consecutiveFailures, Self.backoff.count - 1)]
    }

    private let feed: FeedClient
    private let routes: RouteClient
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    @ObservationIgnored private var home: Home?
    @ObservationIgnored private var criteria = NearbyCriteria()
    @ObservationIgnored private var quietHours = QuietHours.default
    @ObservationIgnored private var consecutiveFailures = 0
    /// nil value = looked up, no route found. Missing key = not looked up yet (or the lookup failed).
    @ObservationIgnored private var routeCache: [String: Route?] = [:]
    @ObservationIgnored private var lastCurrentAt: [String: Date] = [:]
    @ObservationIgnored private var loop: Task<Void, Never>?

    public init(
        feed: FeedClient,
        routes: RouteClient,
        now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.feed = feed
        self.routes = routes
        self.now = now
        self.calendar = calendar
    }

    public func configure(home: Home?, criteria: NearbyCriteria, quietHours: QuietHours) {
        self.home = home
        self.criteria = criteria
        self.quietHours = quietHours
    }

    public func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                try? await Task.sleep(for: self.nextDelay)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    public func tick() async {
        guard let home else { return }
        let time = now()

        if quietHours.isQuiet(at: time, calendar: calendar) {
            status = .quiet
            current = nil
            return
        }

        let aircraft: [Aircraft]
        do {
            aircraft = try await feed.aircraft(near: home.coordinate)
            consecutiveFailures = 0
            status = .idle
        } catch {
            consecutiveFailures += 1
            status = .offline
            current = nil
            return
        }

        guard let nearby = Nearby.closest(in: aircraft, home: home, criteria: criteria) else {
            current = nil
            return
        }

        let hex = nearby.aircraft.hex
        let isNewPass = lastCurrentAt[hex].map { time.timeIntervalSince($0) > Self.reannounceAfter } ?? true
        lastCurrentAt[hex] = time

        let route = await route(for: nearby.aircraft)
        let sighting = Sighting(
            plane: nearby,
            route: route,
            phase: Phase.classify(nearby.aircraft, route: route),
            seenAt: time
        )
        current = sighting
        lastSeen = sighting
        if isNewPass { onNewPlane?(sighting) }
    }

    private func route(for aircraft: Aircraft) async -> Route? {
        guard let callsign = aircraft.callsign else { return nil }
        if let cached = routeCache[callsign] { return cached }
        do {
            let route = try await routes.route(callsign: callsign, position: aircraft.coordinate)
            routeCache[callsign] = .some(route)
            return route
        } catch {
            return nil
        }
    }
}
