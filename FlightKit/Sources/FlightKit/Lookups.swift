public enum Lookups {
    public struct Airline: Sendable, Equatable {
        public let name: String
        public let iata: String
    }

    /// Returns the airline for callsigns shaped like an ICAO prefix followed by a flight number (e.g. `UAL1365`).
    public static func airline(forCallsign callsign: String) -> Airline? {
        let chars = Array(callsign)
        guard chars.count > 3, chars[..<3].allSatisfy({ $0.isUppercase && $0.isLetter }), chars[3].isNumber else {
            return nil
        }
        return airlines[String(chars[..<3])]
    }

    public static func typicalSeats(forTypeCode typeCode: String) -> Int? {
        seats[typeCode]
    }

    private static let airlines: [String: Airline] = [
        "UAL": Airline(name: "United Airlines", iata: "UA"),
        "AAL": Airline(name: "American Airlines", iata: "AA"),
        "DAL": Airline(name: "Delta Air Lines", iata: "DL"),
        "SWA": Airline(name: "Southwest Airlines", iata: "WN"),
        "JBU": Airline(name: "JetBlue", iata: "B6"),
        "NKS": Airline(name: "Spirit Airlines", iata: "NK"),
        "FFT": Airline(name: "Frontier Airlines", iata: "F9"),
        "ASA": Airline(name: "Alaska Airlines", iata: "AS"),
        "SKW": Airline(name: "SkyWest Airlines", iata: "OO"),
        "RPA": Airline(name: "Republic Airways", iata: "YX"),
        "ENY": Airline(name: "Envoy Air", iata: "MQ"),
        "EDV": Airline(name: "Endeavor Air", iata: "9E"),
        "JIA": Airline(name: "PSA Airlines", iata: "OH"),
        "PDT": Airline(name: "Piedmont Airlines", iata: "PT"),
        "ASH": Airline(name: "Mesa Airlines", iata: "YV"),
        "GJS": Airline(name: "GoJet Airlines", iata: "G7"),
        "AWI": Airline(name: "Air Wisconsin", iata: "ZW"),
        "BRE": Airline(name: "Breeze Airways", iata: "MX"),
        "AAY": Airline(name: "Allegiant Air", iata: "G4"),
        "FDX": Airline(name: "FedEx", iata: "FX"),
        "UPS": Airline(name: "UPS Airlines", iata: "5X"),
        "ACA": Airline(name: "Air Canada", iata: "AC"),
        "JZA": Airline(name: "Jazz Aviation", iata: "QK"),
    ]

    private static let seats: [String: Int] = [
        "A319": 128, "A320": 150, "A321": 190, "A20N": 150, "A21N": 196,
        "B737": 143, "B738": 166, "B739": 179, "B38M": 166, "B39M": 178,
        "B752": 176, "B763": 211, "B772": 300, "B789": 257,
        "CRJ2": 50, "CRJ7": 70, "CRJ9": 76,
        "E145": 50, "E170": 70, "E75L": 76, "E75S": 76,
        "BCS1": 109, "BCS3": 130, "DH8D": 74,
    ]
}
