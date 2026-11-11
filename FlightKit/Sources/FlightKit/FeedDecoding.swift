import Foundation

public enum FeedDecoding {
    public static func aircraft(from data: Data) throws -> [Aircraft] {
        try JSONDecoder().decode(Envelope.self, from: data).aircraft.compactMap(\.value?.aircraft)
    }
}

private struct Envelope: Decodable {
    let aircraft: [Lossy<Record>]
}

/// Decodes one element without failing the whole array when that element is malformed.
private struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? decoder.singleValueContainer().decode(T.self)
    }
}

private struct Record: Decodable {
    let hex: String
    let flight: String?
    let r: String?
    let t: String?
    let desc: String?
    let ownOp: String?
    let year: String?
    let altBaro: Altitude?
    let gs: Double?
    let baroRate: Int?
    let squawk: String?
    let category: String?
    let lat: Double?
    let lon: Double?

    enum CodingKeys: String, CodingKey {
        case hex, flight, r, t, desc, ownOp, year, gs, squawk, category, lat, lon
        case altBaro = "alt_baro"
        case baroRate = "baro_rate"
    }

    var aircraft: Aircraft? {
        guard let lat, let lon else { return nil }
        return Aircraft(
            hex: hex,
            callsign: flight.nonBlank,
            registration: r.nonBlank,
            typeCode: t.nonBlank,
            typeDescription: desc.nonBlank,
            operatorName: ownOp.nonBlank,
            yearBuilt: year.nonBlank.flatMap(Int.init),
            altitudeFeet: altBaro?.feet,
            groundSpeedKnots: gs,
            verticalRateFpm: baroRate,
            squawk: squawk.nonBlank,
            category: category.nonBlank,
            coordinate: Coordinate(latitude: lat, longitude: lon)
        )
    }
}

/// adsb.fi sends either a number of feet or the string "ground".
private enum Altitude: Decodable {
    case feet(Int)
    case ground

    /// Anything outside this is corrupt feed data; rejecting it also keeps the Int conversion from trapping.
    static let plausibleFeet = -2_000.0...100_000.0

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let value = try? container.decode(Double.self) else {
            self = .ground
            return
        }
        guard Self.plausibleFeet.contains(value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Implausible altitude \(value)")
        }
        self = .feet(Int(value.rounded()))
    }

    var feet: Int? {
        if case .feet(let value) = self { value } else { nil }
    }
}

private extension Optional<String> {
    var nonBlank: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
