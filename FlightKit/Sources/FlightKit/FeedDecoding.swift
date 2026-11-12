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
    let altGeom: Altitude?
    let gs: Double?
    let track: Double?
    let baroRate: Int?
    let squawk: String?
    let category: String?
    /// Bit 1 is military; the others (interesting, PIA, LADD) aren't used. Lossy because it only adds a
    /// badge, so a malformed value must not drop the whole plane.
    let dbFlags: Lossy<Int>?
    let lat: Double?
    let lon: Double?

    enum CodingKeys: String, CodingKey {
        case hex, flight, r, t, desc, ownOp, year, gs, track, squawk, category, dbFlags, lat, lon
        case altBaro = "alt_baro"
        case altGeom = "alt_geom"
        case baroRate = "baro_rate"
    }

    /// GPS altitude is within ~150 ft of sea-level height over the US; pressure altitude isn't corrected for
    /// the day's air pressure and can be off by ~1,000 ft. "ground" from the transponder always wins.
    private var altitudeFeet: Int? {
        altBaro?.feet.map { baro in altGeom?.feet ?? baro }
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
            altitudeFeet: altitudeFeet,
            groundSpeedKnots: gs.flatMap { (0...2_000).contains($0) ? $0 : nil },
            verticalRateFpm: baroRate,
            squawk: squawk.nonBlank,
            category: category.nonBlank,
            isMilitary: (dbFlags?.value ?? 0) & 1 != 0,
            trackDegrees: track.flatMap { (0..<360).contains($0) ? $0 : nil },
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
