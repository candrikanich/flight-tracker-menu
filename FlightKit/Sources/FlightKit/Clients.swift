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
private func get(_ url: URL, using fetch: HTTPFetch) async throws -> Data? {
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
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

    /// Tries adsbdb, then adsb.lol, and keeps the first route that fits where the plane actually is.
    public func route(callsign: String, position: Coordinate) async throws -> Route? {
        guard callsign.wholeMatch(of: /[A-Z]{3}[0-9][0-9A-Z]{0,4}/) != nil else { return nil }

        let sources: [(URL, (Data) -> Route?)] = [
            (URL(string: "https://api.adsbdb.com/v0/callsign/\(callsign)")!, RouteDecoding.adsbdbRoute),
            (URL(string: "https://vrs-standing-data.adsb.lol/routes/\(callsign.prefix(2))/\(callsign).json")!,
             RouteDecoding.adsbLolRoute),
        ]
        for (url, decode) in sources {
            if let data = try await get(url, using: fetch), let route = decode(data),
               RouteDecoding.isPlausible(route, for: position) {
                return route
            }
        }
        return nil
    }
}

public struct ElevationClient: Sendable {
    let fetch: HTTPFetch

    public init(fetch: @escaping HTTPFetch) {
        self.fetch = fetch
    }

    public func groundElevationFeet(at coordinate: Coordinate) async throws -> Double {
        var components = URLComponents(string: "https://epqs.nationalmap.gov/v1/json")!
        components.queryItems = [
            URLQueryItem(name: "x", value: String(coordinate.longitude)),
            URLQueryItem(name: "y", value: String(coordinate.latitude)),
            URLQueryItem(name: "units", value: "Feet"),
            URLQueryItem(name: "wkid", value: "4326"),
        ]
        guard let data = try await get(components.url!, using: fetch) else { throw ClientError.http(status: 404) }
        return try JSONDecoder().decode(Elevation.self, from: data).value
    }

    private struct Elevation: Decodable {
        let value: Double
    }
}
