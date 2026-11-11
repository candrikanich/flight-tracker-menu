import Foundation

public typealias HTTPFetch = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

public enum HTTP {
    public static let urlSession: HTTPFetch = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

public enum ClientError: Error, Equatable {
    case http(status: Int)
}

/// Returns the body for 2xx, nil for 404, and throws for anything else.
private func get(_ url: URL, using fetch: HTTPFetch, timeout: TimeInterval = 15) async throws -> Data? {
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    let (data, response) = try await fetch(request)
    switch response.statusCode {
    case 200..<300: return data
    case 404: return nil
    default: throw ClientError.http(status: response.statusCode)
    }
}

public struct FeedClient: Sendable {
    let fetch: HTTPFetch

    public init(fetch: @escaping HTTPFetch) {
        self.fetch = fetch
    }

    /// Coordinates are rounded to ~1 km so the exact home location never leaves the Mac.
    public func aircraft(near home: Coordinate, radiusNM: Int = 12) async throws -> [Aircraft] {
        let lat = String(format: "%.2f", home.latitude)
        let lon = String(format: "%.2f", home.longitude)
        let url = URL(string: "https://opendata.adsb.fi/api/v2/lat/\(lat)/lon/\(lon)/dist/\(radiusNM)")!
        guard let data = try await get(url, using: fetch) else { return [] }
        return try FeedDecoding.aircraft(from: data)
    }
}

public struct RouteClient: Sendable {
    let fetch: HTTPFetch

    public init(fetch: @escaping HTTPFetch) {
        self.fetch = fetch
    }

    /// Tries adsbdb, then adsb.lol, and keeps the first route (the leg, for a multi-stop flight)
    /// that fits where the plane is.
    public func route(callsign: String, position: Coordinate, verticalRateFpm: Int? = nil) async throws -> Route? {
        guard callsign.wholeMatch(of: /[A-Z]{3}[0-9][0-9A-Z]{0,4}/) != nil else { return nil }

        let sources: [(URL, (Data) -> [Route])] = [
            (URL(string: "https://api.adsbdb.com/v0/callsign/\(callsign)")!,
             { RouteDecoding.adsbdbRoute(from: $0).map { [$0] } ?? [] }),
            (URL(string: "https://vrs-standing-data.adsb.lol/routes/\(callsign.prefix(2))/\(callsign).json")!,
             RouteDecoding.adsbLolLegs),
        ]
        var firstError: Error?
        for (url, decode) in sources {
            do {
                // Short timeout: the tracker waits on this before showing a newly arrived plane.
                if let data = try await get(url, using: fetch, timeout: 5),
                   let route = RouteDecoding.fittingLeg(
                       decode(data), position: position, verticalRateFpm: verticalRateFpm
                   ) {
                    return route
                }
            } catch {
                firstError = firstError ?? error
            }
        }
        // A source that errored might have had the route, so this is "try again later", not "no route".
        if let firstError { throw firstError }
        return nil
    }
}

public struct ElevationClient: Sendable {
    let fetch: HTTPFetch

    public init(fetch: @escaping HTTPFetch) {
        self.fetch = fetch
    }

    /// Rounded to ~100 m: plenty for ground elevation, and the exact home location never leaves the Mac.
    public func groundElevationFeet(at coordinate: Coordinate) async throws -> Double {
        var components = URLComponents(string: "https://epqs.nationalmap.gov/v1/json")!
        components.queryItems = [
            URLQueryItem(name: "x", value: String(format: "%.3f", coordinate.longitude)),
            URLQueryItem(name: "y", value: String(format: "%.3f", coordinate.latitude)),
            URLQueryItem(name: "units", value: "Feet"),
            URLQueryItem(name: "wkid", value: "4326"),
        ]
        // USGS often takes 10–20 s to answer.
        guard let data = try await get(components.url!, using: fetch, timeout: 30) else {
            throw ClientError.http(status: 404)
        }
        return try JSONDecoder().decode(Elevation.self, from: data).value
    }

    private struct Elevation: Decodable {
        let value: Double
    }
}
