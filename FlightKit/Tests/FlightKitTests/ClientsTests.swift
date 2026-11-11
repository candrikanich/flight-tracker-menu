import Foundation
import Testing
@testable import FlightKit

/// Serves canned responses by URL substring and records every request it receives.
final class StubHTTP: @unchecked Sendable {
    private let lock = NSLock()
    private var routes: [(match: String, status: Int, body: Data)] = []
    private var _requests: [URLRequest] = []

    var requests: [URLRequest] { lock.withLock { _requests } }

    func on(_ match: String, status: Int = 200, body: Data = Data()) {
        lock.withLock { routes.append((match, status, body)) }
    }

    var fetch: HTTPFetch {
        { [self] request in
            let url = try #require(request.url)
            let hit = lock.withLock { () -> (Int, Data)? in
                _requests.append(request)
                return routes.last { url.absoluteString.contains($0.match) }.map { ($0.status, $0.body) }
            }
            let (status, body) = hit ?? (404, Data())
            return (body, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }
}

@Suite struct RouteDecodingTests {
    @Test func adsbdbRouteDecodes() throws {
        let route = try #require(RouteDecoding.adsbdbRoute(from: fixture("adsbdb-UAL1365")))
        #expect(route.airlineName == "United Airlines")
        #expect(route.origin.iata == "DFW")
        #expect(route.origin.city == "Dallas-Fort Worth")
        #expect(route.destination.iata == "EWR")
        #expect(route.destination.icao == "KEWR")
    }

    @Test func adsbLolRouteDecodes() throws {
        let route = try #require(RouteDecoding.adsbLolRoute(from: fixture("adsblol-UAL1365")))
        #expect(route.airlineName == nil)
        #expect(route.origin.iata == "SNA")
        #expect(route.origin.city == "Santa Ana")
        #expect(route.destination.iata == "EWR")
    }

    @Test func unknownCallsignDecodesAsNil() throws {
        #expect(RouteDecoding.adsbdbRoute(from: try fixture("adsbdb-unknown")) == nil)
    }

    @Test func plausibilityAtCleveland() throws {
        let dallas = try #require(RouteDecoding.adsbdbRoute(from: fixture("adsbdb-UAL1365")))
        let santaAna = try #require(RouteDecoding.adsbLolRoute(from: fixture("adsblol-UAL1365")))
        let lax = Airport(iata: "LAX", icao: "KLAX", name: "LAX", city: nil, coordinate: Coordinate(latitude: 33.9425, longitude: -118.408))
        let sfo = Airport(iata: "SFO", icao: "KSFO", name: "SFO", city: nil, coordinate: Coordinate(latitude: 37.619, longitude: -122.375))
        #expect(!RouteDecoding.isPlausible(dallas, for: cle))
        #expect(RouteDecoding.isPlausible(santaAna, for: cle))
        #expect(!RouteDecoding.isPlausible(Route(airlineName: nil, origin: lax, destination: sfo), for: cle))
    }
}

@Suite struct ClientsTests {
    @Test func feedClientRoundsCoordinatesAndUses12NauticalMiles() async throws {
        let http = StubHTTP()
        http.on("adsb.fi", body: try fixture("adsbfi-cle"))
        let aircraft = try await FeedClient(fetch: http.fetch).aircraft(near: Coordinate(latitude: 41.4123, longitude: -81.8498))
        #expect(http.requests.first?.url?.absoluteString == "https://opendata.adsb.fi/api/v2/lat/41.41/lon/-81.85/dist/12")
        #expect(aircraft.count == 4)
    }

    @Test func routeClientSkipsImplausibleSourceForPlausibleOne() async throws {
        let http = StubHTTP()
        http.on("adsbdb.com/v0/callsign/UAL1365", body: try fixture("adsbdb-UAL1365"))
        http.on("vrs-standing-data.adsb.lol/routes/UA/UAL1365.json", body: try fixture("adsblol-UAL1365"))
        let route = try await RouteClient(fetch: http.fetch).route(callsign: "UAL1365", position: cle)
        #expect(route?.origin.iata == "SNA")
        #expect(route?.destination.iata == "EWR")
    }

    @Test func routeClientReturnsNilWhenNoSourceFits() async throws {
        let http = StubHTTP()
        http.on("adsbdb.com", body: try fixture("adsbdb-UAL1365"))
        http.on("adsb.lol", status: 404)
        #expect(try await RouteClient(fetch: http.fetch).route(callsign: "UAL1365", position: cle) == nil)
    }

    @Test func routeClientTreatsAdsbdbNotFoundAsNoRoute() async throws {
        let http = StubHTTP()
        http.on("adsbdb.com", status: 404, body: try fixture("adsbdb-unknown"))
        http.on("adsb.lol", body: try fixture("adsblol-UAL1365"))
        #expect(try await RouteClient(fetch: http.fetch).route(callsign: "UAL1365", position: cle)?.origin.iata == "SNA")
    }

    @Test func routeClientMakesNoRequestsForRegistrationCallsigns() async throws {
        let http = StubHTTP()
        #expect(try await RouteClient(fetch: http.fetch).route(callsign: "N5955K", position: cle) == nil)
        #expect(http.requests.isEmpty)
    }

    @Test func serverErrorThrows() async throws {
        let http = StubHTTP()
        http.on("adsb.fi", status: 503)
        await #expect(throws: ClientError.http(status: 503)) {
            try await FeedClient(fetch: http.fetch).aircraft(near: cle)
        }
    }

    @Test func elevationClientDecodesFeet() async throws {
        let http = StubHTTP()
        http.on("epqs.nationalmap.gov", body: try fixture("epqs"))
        let feet = try await ElevationClient(fetch: http.fetch).groundElevationFeet(at: Coordinate(latitude: 41.41, longitude: -81.85))
        #expect(abs(feet - 781.64) < 0.01)
        let url = try #require(http.requests.first?.url?.absoluteString)
        #expect(url.contains("x=-81.85") && url.contains("y=41.41") && url.contains("units=Feet"))
    }

    @Test func elevationClientRoundsCoordinatesToAboutOneHundredMeters() async throws {
        let http = StubHTTP()
        http.on("epqs.nationalmap.gov", body: try fixture("epqs"))
        _ = try await ElevationClient(fetch: http.fetch).groundElevationFeet(at: Coordinate(latitude: 41.412345, longitude: -81.856789))
        let url = try #require(http.requests.first?.url?.absoluteString)
        #expect(url.contains("x=-81.857&y=41.412"))
    }
}
