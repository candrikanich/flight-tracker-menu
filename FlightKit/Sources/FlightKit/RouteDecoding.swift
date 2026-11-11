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

    public static func adsbLolRoute(from data: Data) -> Route? {
        guard let airports = try? JSONDecoder().decode(AdsbLolRoute.self, from: data).airports,
              let origin = airports.first, let destination = airports.last, airports.count >= 2 else {
            return nil
        }
        return Route(airlineName: nil, origin: origin.airport, destination: destination.airport)
    }

    /// Free route databases are keyed by callsign and go stale; a route whose path runs far from where
    /// the plane actually is was almost certainly flown by a different flight with the same number.
    public static func isPlausible(_ route: Route, for position: Coordinate, maxCrossTrackNM: Double = 100) -> Bool {
        Geo.crossTrackNauticalMiles(point: position, from: route.origin.coordinate, to: route.destination.coordinate)
            <= maxCrossTrackNM
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
