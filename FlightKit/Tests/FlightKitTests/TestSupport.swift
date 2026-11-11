import Foundation
@testable import FlightKit

let homeAtSeaLevel = Home(coordinate: Coordinate(latitude: 41.45, longitude: -81.80), groundElevationFeet: 0)

/// A coordinate due north of `origin` by `miles` along the meridian.
func north(of origin: Coordinate, miles: Double) -> Coordinate {
    Coordinate(latitude: origin.latitude + miles / Geo.earthRadiusMiles * 180 / .pi, longitude: origin.longitude)
}

func plane(
    hex: String = "abc123",
    callsign: String? = "UAL1365",
    registration: String? = "N27733",
    typeCode: String? = "B737",
    altitudeFeet: Int? = 2_100,
    verticalRateFpm: Int? = nil,
    category: String? = "A3",
    milesNorth: Double = 0.4,
    of home: Home = homeAtSeaLevel
) -> Aircraft {
    Aircraft(
        hex: hex,
        callsign: callsign,
        registration: registration,
        typeCode: typeCode,
        altitudeFeet: altitudeFeet,
        verticalRateFpm: verticalRateFpm,
        category: category,
        coordinate: north(of: home.coordinate, miles: milesNorth)
    )
}

func airport(_ icao: String, iata: String?, city: String) -> Airport {
    Airport(iata: iata, icao: icao, name: "\(city) Airport", city: city, coordinate: Coordinate(latitude: 0, longitude: 0))
}

let cleToEwr = Route(
    airlineName: "United Airlines",
    origin: airport("KCLE", iata: "CLE", city: "Cleveland"),
    destination: airport("KEWR", iata: "EWR", city: "Newark")
)
let dfwToCle = Route(
    airlineName: nil,
    origin: airport("KDFW", iata: "DFW", city: "Dallas"),
    destination: airport("KCLE", iata: "CLE", city: "Cleveland")
)
let snaToEwr = Route(
    airlineName: nil,
    origin: airport("KSNA", iata: "SNA", city: "Santa Ana"),
    destination: airport("KEWR", iata: "EWR", city: "Newark")
)
