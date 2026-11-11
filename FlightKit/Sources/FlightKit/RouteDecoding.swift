import Foundation

public enum RouteDecoding {
    public static func adsbdbRoute(from data: Data) -> Route? {
        guard let flightroute = try? JSONDecoder().decode(AdsbdbEnvelope.self, from: data).response.flightroute else {
            return nil
        }
        return Route(
            airlineName: flightroute.airline?.name,
            origin: flightroute.origin.airport,
            destination: flightroute.destination.airport
        )
    }

    /// adsb.lol lists every stop of a through-flight; each consecutive pair is one leg.
    public static func adsbLolLegs(from data: Data) -> [Route] {
        guard let airports = try? JSONDecoder().decode(AdsbLolRoute.self, from: data).airports else { return [] }
        return zip(airports, airports.dropFirst()).map {
            Route(airlineName: nil, origin: $0.airport, destination: $1.airport)
        }
    }

    /// The one leg that fits where the plane is. When two legs meet here (a stop at this airport), climbing
    /// means the leg leaving and descending the leg arriving; level or unknown is too ambiguous to state.
    public static func fittingLeg(
        _ legs: [Route],
        position: Coordinate,
        verticalRateFpm: Int?,
        heightAboveGroundFeet: Int? = nil
    ) -> Route? {
        let candidates = legs.filter {
            isPlausible($0, for: position)
                && fitsHeight($0, position: position, verticalRateFpm: verticalRateFpm,
                              heightAboveGroundFeet: heightAboveGroundFeet)
        }
        guard candidates.count > 1 else { return candidates.first }
        switch verticalRateFpm ?? 0 {
        case ...(-Phase.climbOrDescentThresholdFpm):
            return candidates.min { distance($0.destination, position) < distance($1.destination, position) }
        case Phase.climbOrDescentThresholdFpm...:
            return candidates.min { distance($0.origin, position) < distance($1.origin, position) }
        default:
            return nil
        }
    }

    /// Below this, a climbing or descending plane is leaving or landing nearby, not cruising past.
    static let lowTrafficCeilingFeet = 5_000
    /// A 3° approach loses about 300 ft per nautical mile.
    static let feetPerNauticalMileOnApproach = 300.0
    /// Room for base legs, vectors and steeper climbs.
    static let approachSlackNM = 8.0

    /// A low plane that is descending lands within a few miles, and one climbing took off a few miles back;
    /// a stale route whose airport at that end is farther away belongs to a different trip.
    static func fitsHeight(
        _ route: Route,
        position: Coordinate,
        verticalRateFpm: Int?,
        heightAboveGroundFeet: Int?
    ) -> Bool {
        guard let height = heightAboveGroundFeet, height < lowTrafficCeilingFeet else { return true }
        let reachNM = Double(height) / feetPerNauticalMileOnApproach + approachSlackNM
        switch verticalRateFpm ?? 0 {
        case ...(-Phase.climbOrDescentThresholdFpm):
            return Geo.distanceNauticalMiles(route.destination.coordinate, position) <= reachNM
        case Phase.climbOrDescentThresholdFpm...:
            return Geo.distanceNauticalMiles(route.origin.coordinate, position) <= reachNM
        default:
            return true
        }
    }

    private static func distance(_ airport: Airport, _ position: Coordinate) -> Double {
        Geo.distanceMiles(airport.coordinate, position)
    }

    /// Free route databases are keyed by callsign and go stale; a route whose path runs far from where
    /// the plane actually is — off to the side, or beyond either end — was almost certainly flown by a
    /// different flight with the same number.
    public static func isPlausible(
        _ route: Route,
        for position: Coordinate,
        maxCrossTrackNM: Double = 100,
        endMarginNM: Double = 50
    ) -> Bool {
        let (origin, destination) = (route.origin.coordinate, route.destination.coordinate)
        let along = Geo.alongTrackNauticalMiles(point: position, from: origin, to: destination)
        return Geo.crossTrackNauticalMiles(point: position, from: origin, to: destination) <= maxCrossTrackNM
            && along >= -endMarginNM
            && along <= Geo.distanceNauticalMiles(origin, destination) + endMarginNM
    }
}

private struct AdsbdbEnvelope: Decodable {
    struct Response: Decodable {
        let flightroute: FlightRoute?
    }

    struct FlightRoute: Decodable {
        struct Airline: Decodable { let name: String }
        let airline: Airline?
        let origin: AdsbdbAirport
        let destination: AdsbdbAirport
    }

    let response: Response
}

private struct AdsbdbAirport: Decodable {
    let iataCode: String?
    let icaoCode: String
    let name: String
    let municipality: String?
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case name, municipality, latitude, longitude
        case iataCode = "iata_code"
        case icaoCode = "icao_code"
    }

    var airport: Airport {
        Airport(iata: iataCode, icao: icaoCode, name: name, city: municipality,
                coordinate: Coordinate(latitude: latitude, longitude: longitude))
    }
}

private struct AdsbLolRoute: Decodable {
    struct LolAirport: Decodable {
        let name: String
        let icao: String
        let iata: String?
        let location: String?
        let lat: Double
        let lon: Double

        var airport: Airport {
            Airport(iata: iata, icao: icao, name: name, city: location,
                    coordinate: Coordinate(latitude: lat, longitude: lon))
        }
    }

    let airports: [LolAirport]

    enum CodingKeys: String, CodingKey {
        case airports = "_airports"
    }
}
