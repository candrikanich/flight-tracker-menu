import Foundation

public struct Coordinate: Sendable, Hashable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct Home: Sendable, Codable, Equatable {
    public var coordinate: Coordinate
    public var groundElevationFeet: Double

    public init(coordinate: Coordinate, groundElevationFeet: Double) {
        self.coordinate = coordinate
        self.groundElevationFeet = groundElevationFeet
    }
}

public struct Aircraft: Sendable, Equatable, Identifiable {
    public let hex: String
    public let callsign: String?
    public let registration: String?
    public let typeCode: String?
    public let typeDescription: String?
    public let operatorName: String?
    public let yearBuilt: Int?
    /// nil when the aircraft reports it is on the ground.
    public let altitudeFeet: Int?
    public let groundSpeedKnots: Double?
    public let verticalRateFpm: Int?
    public let squawk: String?
    public let category: String?
    public let coordinate: Coordinate

    public var id: String { hex }

    public init(
        hex: String,
        callsign: String? = nil,
        registration: String? = nil,
        typeCode: String? = nil,
        typeDescription: String? = nil,
        operatorName: String? = nil,
        yearBuilt: Int? = nil,
        altitudeFeet: Int?,
        groundSpeedKnots: Double? = nil,
        verticalRateFpm: Int? = nil,
        squawk: String? = nil,
        category: String? = nil,
        coordinate: Coordinate
    ) {
        self.hex = hex
        self.callsign = callsign
        self.registration = registration
        self.typeCode = typeCode
        self.typeDescription = typeDescription
        self.operatorName = operatorName
        self.yearBuilt = yearBuilt
        self.altitudeFeet = altitudeFeet
        self.groundSpeedKnots = groundSpeedKnots
        self.verticalRateFpm = verticalRateFpm
        self.squawk = squawk
        self.category = category
        self.coordinate = coordinate
    }
}

public struct Airport: Sendable, Equatable {
    public let iata: String?
    public let icao: String
    public let name: String
    public let city: String?
    public let coordinate: Coordinate

    public init(iata: String?, icao: String, name: String, city: String?, coordinate: Coordinate) {
        self.iata = iata
        self.icao = icao
        self.name = name
        self.city = city
        self.coordinate = coordinate
    }
}

public struct Route: Sendable, Equatable {
    public let airlineName: String?
    public let origin: Airport
    public let destination: Airport

    public init(airlineName: String?, origin: Airport, destination: Airport) {
        self.airlineName = airlineName
        self.origin = origin
        self.destination = destination
    }
}

public enum TrafficFilter: String, CaseIterable, Sendable, Codable {
    case airport, passingOver, all
}

public enum FlightPhase: Sendable, Equatable {
    case arriving, departing, passingOver
}
