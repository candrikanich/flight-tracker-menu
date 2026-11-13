import Foundation

/// Which way CLE is using its parallel runways. Planes land and take off into the wind, so all of them
/// share one direction at a time.
public enum RunwayFlow: Sendable, Equatable { case runway6, runway24 }

public enum OverHome: Sendable, Equatable { case arrivals, departures }

/// Infers the runway in use from low traffic climbing or descending along the runway line,
/// using the feed the app already polls. No wind data: what the planes are doing is the answer.
public struct RunwayFlowWatch: Sendable, Equatable {
    public static let airport = Coordinate(latitude: 41.4117, longitude: -81.8498)
    /// 06/24 are about 060°/240° magnetic; with roughly 8° west variation that's 052°/232° true, which is
    /// what the feed's track uses. The tolerance below absorbs any error in that.
    static let runway6TrackDegrees = 52.0
    static let trackToleranceDegrees = 30.0
    /// About 3,200 ft above the field: low enough to be landing or just departed, not passing over.
    static let maxAltitudeFeet = 4_000
    /// Works only because the feed asks for 12 NM around home, which covers this circle when home is within
    /// about 5 NM of CLE. Farther out, part of it goes unseen and the line just stays hidden more often.
    static let maxMilesFromAirport = 8.0
    /// The flow changes with the wind; older traffic says nothing about now.
    public static let window: TimeInterval = 20 * 60
    static let minimumAircraft = 2
    static let agreement = 0.75
    /// Farther than this to the side of the extended runway line, nothing lines up over home.
    static let maxNauticalMilesOffRunwayLine = 1.5
    static let maxNauticalMilesAlongRunwayLine = 12.0
    /// The airport point is mid-field, so an arrival can be this far past it over the runway, and a
    /// departure this far short of it on its takeoff roll.
    static let fieldHalfLengthNauticalMiles = 1.0

    /// A point a few miles out along runway 6; a degree of longitude is shorter than one of latitude here.
    private static let runway6Axis: Coordinate = {
        let heading = runway6TrackDegrees * .pi / 180
        return Coordinate(
            latitude: airport.latitude + 0.05 * cos(heading),
            longitude: airport.longitude + 0.05 * sin(heading) / cos(airport.latitude * .pi / 180)
        )
    }()

    private struct Vote: Sendable, Equatable {
        let flow: RunwayFlow
        let time: Date
    }

    /// One vote per aircraft, its latest, so a plane seen on many checks counts once.
    private var votes: [String: Vote] = [:]

    public init() {}

    mutating func record(_ aircraft: [Aircraft], at time: Date) {
        for plane in aircraft {
            if let flow = Self.flow(of: plane) { votes[plane.hex] = Vote(flow: flow, time: time) }
        }
        votes = votes.filter { time.timeIntervalSince($0.value.time) <= Self.window }
    }

    /// nil until enough recent traffic agrees: an honest "don't know" beats a guess.
    public func flow(now: Date) -> RunwayFlow? {
        let recent = votes.values.filter { now.timeIntervalSince($0.time) <= Self.window }.map(\.flow)
        guard recent.count >= Self.minimumAircraft else { return nil }
        let toward6 = recent.filter { $0 == .runway6 }.count
        let leader: RunwayFlow = toward6 * 2 >= recent.count ? .runway6 : .runway24
        let leaderCount = leader == .runway6 ? toward6 : recent.count - toward6
        return Double(leaderCount) / Double(recent.count) >= Self.agreement ? leader : nil
    }

    /// Landing on 6 means arriving from the southwest and departing to the northeast. A home on the
    /// southwest side of the field gets the arrivals; on the northeast side, the departures.
    public static func overHome(_ flow: RunwayFlow, home: Coordinate) -> OverHome? {
        let across = Geo.crossTrackNauticalMiles(point: home, from: airport, to: runway6Axis)
        let along = Geo.alongTrackNauticalMiles(point: home, from: airport, to: runway6Axis)
        guard across <= maxNauticalMilesOffRunwayLine, abs(along) <= maxNauticalMilesAlongRunwayLine else {
            return nil
        }
        let homeIsSouthwest = along < 0
        return (flow == .runway6) == homeIsSouthwest ? .arrivals : .departures
    }

    /// Only planes on the extended runway line, at the end that fits what they're doing: a downwind leg or a
    /// departure turning back flies a runway heading too, but says nothing about which way the runway is used.
    private static func flow(of plane: Aircraft) -> RunwayFlow? {
        guard plane.category != "A7",
              let altitude = plane.altitudeFeet, altitude <= maxAltitudeFeet,
              let rate = plane.verticalRateFpm, abs(rate) >= Phase.climbOrDescentThresholdFpm,
              let track = plane.trackDegrees,
              Geo.distanceMiles(plane.coordinate, airport) <= maxMilesFromAirport,
              Geo.crossTrackNauticalMiles(point: plane.coordinate, from: airport, to: runway6Axis)
                <= maxNauticalMilesOffRunwayLine else { return nil }
        let flow: RunwayFlow
        if angle(track, runway6TrackDegrees) <= trackToleranceDegrees {
            flow = .runway6
        } else if angle(track, runway6TrackDegrees + 180) <= trackToleranceDegrees {
            flow = .runway24
        } else {
            return nil
        }
        let along = Geo.alongTrackNauticalMiles(point: plane.coordinate, from: airport, to: runway6Axis)
        let pastField = flow == .runway6 ? along : -along
        let isArriving = rate < 0
        let fitsItsEnd = isArriving
            ? pastField <= fieldHalfLengthNauticalMiles
            : pastField >= -fieldHalfLengthNauticalMiles
        return fitsItsEnd ? flow : nil
    }

    private static func angle(_ a: Double, _ b: Double) -> Double {
        abs((a - b + 540).truncatingRemainder(dividingBy: 360) - 180)
    }
}

extension Formatting {
    /// Runway numbers without L/R/C: the planes say which direction, not which of the parallels.
    public static func runwayLine(_ flow: RunwayFlow, overHome: OverHome?) -> String {
        let runway = "CLE landing on runway \(flow == .runway6 ? "6" : "24")"
        switch overHome {
        case .arrivals: return "\(runway) · arrivals over you"
        case .departures: return "\(runway) · departures over you"
        case nil: return runway
        }
    }
}
