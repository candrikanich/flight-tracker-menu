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
    /// Lossy like `dbFlags`: these only add words to the card, so a bad value must not drop the plane.
    let navAltitudeMcp: Lossy<Double>?
    let emergency: Lossy<String>?
    let category: String?
    /// Bit 1 is military; the others (interesting, PIA, LADD) aren't used. Lossy because it only adds a
    /// badge, so a malformed value must not drop the whole plane.
    let dbFlags: Lossy<Int>?
    let lat: Double?
    let lon: Double?

    enum CodingKeys: String, CodingKey {
        case hex, flight, r, t, desc, ownOp, year, gs, track, squawk, category, dbFlags, lat, lon
        case emergency
        case navAltitudeMcp = "nav_altitude_mcp"
        case altBaro = "alt_baro"
        case altGeom = "alt_geom"
        case baroRate = "baro_rate"
    }

    /// GPS altitude is within ~150 ft of sea-level height over the US; pressure altitude isn't corrected for
    /// the day's air pressure and can be off by ~1,000 ft. "ground" from the transponder always wins.
    private var altitudeFeet: Int? {
        altBaro?.feet.map { baro in altGeom?.feet ?? baro }
    }

    /// The feed packs the selected altitude into 16 ft steps, so 33,000 arrives as 33,024. Some avionics send 0
    /// when nothing is set, and anything under 1,000 ft is below Cleveland's pattern altitude anyway.
    private var targetAltitudeFeet: Int? {
        guard let feet = navAltitudeMcp?.value, (1_000...60_000).contains(feet) else { return nil }
        return Int((feet / 100).rounded()) * 100
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
            pressureAltitudeFeet: altBaro?.feet,
            groundSpeedKnots: gs.flatMap { (0...2_000).contains($0) ? $0 : nil },
            verticalRateFpm: baroRate,
            targetAltitudeFeet: targetAltitudeFeet,
            squawk: squawk.nonBlank,
            category: category.nonBlank,
            isMilitary: (dbFlags?.value ?? 0) & 1 != 0,
            isMedicalFlight: emergency?.value == "lifeguard",
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
