# Flight Overhead Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed macOS menu-bar app that shows, live and quietly, the plane passing over Chris's house near CLE, with a click-open detail card.

**Architecture:** A platform-independent Swift package `FlightKit` holds every decision (decoding feeds, geometry, which plane counts as "nearby", phase, formatting, quiet hours) as pure, unit-tested functions, plus thin HTTP clients and an `@Observable` `FlightTracker` that polls and publishes state. A thin macOS app target (`FlightOverhead`, generated with XcodeGen) renders that state using AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI views, a SwiftUI Settings window, and silent notifications.

**Tech Stack:** Swift 6.4 (strict concurrency), SwiftUI + AppKit, Observation, MapKit (geocoding/pin), UserNotifications, ServiceManagement (`SMAppService`), XcodeGen 2.x, Swift Testing (`import Testing`). No third-party packages.

**Spec:** `docs/superpowers/specs/2026-11-11-flight-overhead-design.md`

## Global Constraints

- macOS deployment target 15.0; built with Xcode 27.1. Swift language mode 6.
- No third-party dependencies. XcodeGen is a dev tool only (`project.yml` committed, `.xcodeproj` git-ignored).
- **Never play a sound.** Notifications use `content.sound = nil`. No pulsing, blinking, or animated transitions in the menu bar (`NSAnimationContext` duration 0 / no `withAnimation`).
- Unknown route renders exactly `route unknown`. Seat capacity renders as `~N seats` and is labelled "typical capacity".
- Data sources (verified live 2026-11-11):
  - Positions: `GET https://opendata.adsb.fi/api/v2/lat/{lat}/lon/{lon}/dist/{nm}` → `{"now":…, "aircraft":[…]}`. Rate limit: ≤ 1 req/s; we poll every 5 s.
  - Routes (two free sources, both sometimes wrong — verified: for UAL1365 adsbdb said DFW→EWR, 150 nm off the plane's position; adsb.lol said SNA→EWR, 41 nm off):
    - A: `GET https://api.adsbdb.com/v0/callsign/{CALLSIGN}` → `response.flightroute{airline{name,iata}, callsign_iata, origin{iata_code,icao_code,name,municipality,latitude,longitude}, destination{…}}`; 404 or `"response":"unknown callsign"` → none.
    - B: `GET https://vrs-standing-data.adsb.lol/routes/{first 2 chars}/{CALLSIGN}.json` (e.g. `/routes/UA/UAL1365.json`) → `{airline_code, _airport_codes_iata, _airports:[{name,icao,iata,location,lat,lon}, …]}`; first airport = origin, last = destination; 404 → none.
    - Use the first route (A, then B) that passes the plausibility check; otherwise `route unknown`.
  - Photos: `GET https://api.planespotters.net/pub/photos/reg/{REG}` → `photos[0]{thumbnail_large.src, link, photographer}`. **Requires a descriptive `User-Agent` with a contact URL** or it returns 403.
  - Elevation: `GET https://epqs.nationalmap.gov/v1/json?x={lon}&y={lat}&units=Feet&wkid=4326` → `{"value": 781.64}`.
- Feed queries send home coordinates rounded to 2 decimal places (~1 km) with a 12 nm radius; all distance filtering is on-device.
- App Sandbox ON with `com.apple.security.network.client`. `LSUIElement = YES` (no Dock icon). Signed with Chris's Developer ID team; notarized; installed to `/Applications`.
- No Location Services permission in v1.
- Settings defaults: style `liveText`, traffic filter `airport`, radius 1.5 mi, high-traffic min elevation angle 40°, notifications off, quiet hours off (22:00–07:00 when enabled), launch at login off.

## Review Focus

1. **Feed field oddities:** `alt_baro` is the string `"ground"`; `flight` is space-padded (`"UAL1365 "`) or absent; `t`/`r`/`desc`/`year`/`baro_rate` may be missing; airport ground vehicles (`category` `"C1"`/`"C2"`) appear. Expect: decode never fails the whole list; ground/vehicles never shown. → Task 2 tests.
2. **Wrong route from a free lookup** (verified: adsbdb's DFW→EWR for UAL1365 was 150 nm off; adsb.lol's SNA→EWR was right). Expect: the implausible source is skipped in favor of the plausible one; if neither fits within 100 nm, `route unknown`. → Task 4 tests.
3. **Network down / feed 429 / 5xx.** Expect: menu bar shows a dimmed idle icon, no error text, polling backs off (5 → 10 → 20 → 60 s cap) and recovers on success. → Task 5 test.
4. **Quiet hours spanning midnight** (22:00–07:00). Expect: 23:30 and 06:59 are quiet; 07:00 and 21:59 are not. → Task 3 test.
5. **Busy sky / same plane re-entering range.** Expect: one notification per plane per pass (keyed by `hex`, reset after it's been out of range ≥ 2 min); live text always shows the single closest qualifying plane. → Tasks 3 and 5 tests.

---

## File Structure

```
project.yml                                 XcodeGen spec (app target + local FlightKit package)
FlightKit/Package.swift                     macOS 15 / iOS 18 library + tests
FlightKit/Sources/FlightKit/
  Models.swift          Aircraft, Airport, Route, AircraftPhoto, Home, TrafficFilter, FlightPhase, NearbyPlane
  Geo.swift             distance, cross-track, elevation angle
  FeedDecoding.swift    adsb.fi JSON → [Aircraft]
  Nearby.swift          qualification + closest selection
  Phase.swift           arriving / departing / passing over
  Lookups.swift         airline prefixes + seat capacity tables
  Formatting.swift      menu-bar text, card strings
  QuietHours.swift      schedule check
  RouteDecoding.swift   adsbdb JSON → Route?, plausibility
  Clients.swift         HTTP seam + feed/route/photo/elevation clients
  FlightTracker.swift   @Observable polling state machine
FlightKit/Tests/FlightKitTests/             one test file per source file + Fixtures/*.json
App/
  FlightOverheadApp.swift   @main, AppDelegate wiring
  StatusItemController.swift NSStatusItem + NSPopover, style handling
  FlightCardView.swift       detail card
  SettingsView.swift         settings window
  AppSettings.swift          @AppStorage-backed settings
  Notifier.swift             silent notifications
  Info.plist, FlightOverhead.entitlements
scripts/release.sh            archive, notarize, install
```

---

### Task 1: FlightKit package, models, geometry

**Files:**
- Create: `.gitignore` (add `*.xcodeproj`, `.build/`, `build/`), `FlightKit/Package.swift`, `FlightKit/Sources/FlightKit/Models.swift`, `FlightKit/Sources/FlightKit/Geo.swift`
- Test: `FlightKit/Tests/FlightKitTests/GeoTests.swift`

**Interfaces:**
- Produces:
  - `struct Coordinate: Sendable, Hashable, Codable { var latitude: Double; var longitude: Double }`
  - `struct Home: Sendable, Codable, Equatable { var coordinate: Coordinate; var groundElevationFeet: Double }`
  - `struct Aircraft: Sendable, Equatable, Identifiable { let hex: String; let callsign: String?; let registration: String?; let typeCode: String?; let typeDescription: String?; let operatorName: String?; let yearBuilt: Int?; let altitudeFeet: Int?  /* nil when on ground */; let groundSpeedKnots: Double?; let verticalRateFpm: Int?; let squawk: String?; let category: String?; let coordinate: Coordinate; var id: String { hex } }`
  - `struct Airport: Sendable, Equatable { let iata: String?; let icao: String; let name: String; let city: String?; let coordinate: Coordinate }`
  - `struct Route: Sendable, Equatable { let airlineName: String?; let origin: Airport; let destination: Airport }`
  - `struct AircraftPhoto: Sendable, Equatable { let imageURL: URL; let pageURL: URL; let photographer: String }`
  - `enum TrafficFilter: String, CaseIterable, Sendable, Codable { case airport, passingOver, all }`
  - `enum FlightPhase: Sendable, Equatable { case arriving, departing, passingOver }`
  - `enum Geo { static func distanceMiles(_ a: Coordinate, _ b: Coordinate) -> Double; static func crossTrackNauticalMiles(point: Coordinate, from: Coordinate, to: Coordinate) -> Double; static func elevationAngleDegrees(heightFeet: Double, horizontalMiles: Double) -> Double }`

- [ ] **Step 1: Write failing tests** in `GeoTests.swift`:
  - `distanceMiles(CLE (41.4117,-81.8498), DEN (39.8617,-104.6731))` ≈ 1,199 mi ± 5.
  - `distanceMiles(x, x) == 0`.
  - From CLE (41.4117,-81.8498): cross-track to SNA (33.6757,-117.868) → EWR (40.6925,-74.1687) ≈ 41 nm ± 2; to DFW (32.8968,-97.038) → EWR ≈ 150 nm ± 3; to LAX (33.9425,-118.408) → SFO (37.619,-122.375) > 1,000 nm. (Values verified with an independent haversine computation.)
  - `elevationAngleDegrees(heightFeet: 35_000, horizontalMiles: 0)` == 90; `(heightFeet: 5280, horizontalMiles: 1)` == 45 ± 0.01.
- [ ] **Step 2:** `cd FlightKit && swift test --filter GeoTests` → FAIL (types not defined).
- [ ] **Step 3:** Write `Package.swift` (tools 6.0, platforms `.macOS(.v15), .iOS(.v18)`, library `FlightKit`, test target with `resources: [.process("Fixtures")]`), `Models.swift`, `Geo.swift` (haversine, Earth radius 3958.8 mi / 3440.065 nm; standard cross-track formula; `atan2`).
- [ ] **Step 4:** `swift test --filter GeoTests` → PASS.
- [ ] **Step 5:** Commit `feat: add FlightKit models and geometry`.

### Task 2: Decode the adsb.fi feed

**Files:**
- Create: `FlightKit/Sources/FlightKit/FeedDecoding.swift`, `FlightKit/Tests/FlightKitTests/Fixtures/adsbfi-cle.json`
- Test: `FlightKit/Tests/FlightKitTests/FeedDecodingTests.swift`

**Interfaces:**
- Consumes: `Aircraft`, `Coordinate` (Task 1)
- Produces: `enum FeedDecoding { static func aircraft(from data: Data) throws -> [Aircraft] }`

- [ ] **Step 1:** Save a fixture by running `curl -s "https://opendata.adsb.fi/api/v2/lat/41.41/lon/-81.85/dist/40" > …/adsbfi-cle.json`, then hand-edit it so it contains at least: one airliner with every field (`"flight":"UAL1365 "`, `"r":"N27733"`, `"t":"B737"`, `"desc":"BOEING 737-700"`, `"year":"1999"`, `"alt_baro":39000`, `"gs":450.1`, `"baro_rate":0`, `"squawk":"1234"`); one with `"alt_baro":"ground"`; one ground vehicle (`"category":"C2"`, no `t`); one with no `flight`; one with no `lat`/`lon`.
- [ ] **Step 2: Write failing tests** in `FeedDecodingTests.swift`:
  - the airliner decodes to `callsign == "UAL1365"` (trimmed), `yearBuilt == 1999`, `altitudeFeet == 39000`, `typeDescription == "BOEING 737-700"`.
  - `"ground"` decodes to `altitudeFeet == nil`.
  - the record without `flight` decodes with `callsign == nil`.
  - the record without a position is dropped; the total count is the fixture count minus 1.
  - malformed JSON `Data("{".utf8)` throws.
- [ ] **Step 3:** `swift test --filter FeedDecodingTests` → FAIL.
- [ ] **Step 4:** Implement with a private `Decodable` DTO. `alt_baro` decodes as `Int` or the string `"ground"`, `year` as a string → `Int?`, and per-record failures drop that record instead of failing the whole list. Empty strings become nil.
- [ ] **Step 5:** `swift test --filter FeedDecodingTests` → PASS.
- [ ] **Step 6:** Commit `feat: decode adsb.fi aircraft feed`.

### Task 3: Nearby selection, phase, lookups, formatting, quiet hours

**Files:**
- Create: `Nearby.swift`, `Phase.swift`, `Lookups.swift`, `Formatting.swift`, `QuietHours.swift` (all in `FlightKit/Sources/FlightKit/`)
- Test: `NearbyTests.swift`, `PhaseTests.swift`, `FormattingTests.swift`, `QuietHoursTests.swift`

**Interfaces:**
- Consumes: Task 1 models, `Geo`
- Produces:
  - `struct NearbyCriteria: Sendable, Equatable { var filter: TrafficFilter; var radiusMiles: Double = 1.5; var minElevationAngleDegrees: Double = 40; static let highAltitudeThresholdFeet = 10_000 }`
  - `struct NearbyPlane: Sendable, Equatable { let aircraft: Aircraft; let heightAboveHomeFeet: Int; let distanceMiles: Double }`
  - `enum Nearby { static func closest(in: [Aircraft], home: Home, criteria: NearbyCriteria) -> NearbyPlane?; static func qualifies(_: Aircraft, home: Home, criteria: NearbyCriteria) -> NearbyPlane? }`
  - `enum Phase { static func classify(_ plane: Aircraft, route: Route?, homeAirportICAO: String = "KCLE") -> FlightPhase }`
  - `enum Lookups { struct Airline: Sendable, Equatable { let name: String; let iata: String }; static func airline(forCallsign: String) -> Airline?; static func typicalSeats(forTypeCode: String) -> Int? }`
  - `enum Formatting { static func menuBarText(_ plane: NearbyPlane, route: Route?) -> String; static func mph(knots: Double) -> Int; static func flightLabel(callsign: String?, registration: String?) -> String }`
  - `struct QuietHours: Sendable, Codable, Equatable { var isEnabled: Bool; var startMinutes: Int /* 22*60 */; var endMinutes: Int /* 7*60 */; func isQuiet(at date: Date, calendar: Calendar) -> Bool }`

Rules the tests pin:
- **Qualifies:** excludes `altitudeFeet == nil` and `category` starting with `"C"`. Below 10,000 ft above the house: horizontal distance ≤ `radiusMiles`. At or above 10,000 ft: `elevationAngleDegrees ≥ minElevationAngleDegrees`. Filter `airport` keeps only < 10,000, `passingOver` only ≥ 10,000, `all` keeps both. Height above home = `altitudeFeet − groundElevationFeet`, rounded.
- **Closest:** the smallest horizontal distance among qualifiers.
- **Phase:** if a route exists and `destination.icao == homeAirportICAO` → `.arriving`; `origin.icao == homeAirportICAO` → `.departing`. Without a route, below 10,000 ft: `verticalRateFpm ≤ −300` → `.arriving`, `≥ 300` → `.departing`. Everything else → `.passingOver`.
- **Airline prefixes:** ICAO 3-letter prefix followed by a digit. Each entry holds the name and IATA code (e.g. UAL → United Airlines / UA). The table includes at least UAL United, AAL American, DAL Delta, SWA Southwest, JBU JetBlue, NKS Spirit, FFT Frontier, ASA Alaska, SKW SkyWest, RPA Republic, ENY Envoy, EDV Endeavor, JIA PSA, PDT Piedmont, ASH Mesa, GJS GoJet, AWI Air Wisconsin, BRE Breeze, AAY Allegiant, FDX FedEx, UPS UPS, ACA Air Canada, JZA Jazz.
- **Seats:** at least A319 128, A320 150, A321 190, A20N 150, A21N 196, B737 143, B738 166, B739 179, B38M 166, B39M 178, B752 176, B763 211, B772 300, B789 257, CRJ2 50, CRJ7 70, CRJ9 76, E145 50, E170 70, E75L 76, E75S 76, BCS1 109, BCS3 130, DH8D 74.
- **Menu bar text:** `"✈︎ UA1365 → EWR · 0.4 mi · 2,100 ft"`. Uses the IATA flight number built from the airline table (`UAL1365` → `UA1365`), else the raw callsign, else the registration. The destination comes from `route.destination.iata ?? icao`. Without a route: `"✈︎ UAL1365 · 0.4 mi · 2,100 ft"`. One decimal place for miles; thousands separator for feet.

- [ ] **Step 1: Write failing tests** for each rule above, using the exact values. Include these boundaries: a plane at exactly 1.5 mi qualifies, 1.51 does not; at 35,000 ft, 7.5 mi qualifies at 40° and 9 mi does not; a ground vehicle never qualifies; `QuietHours(isEnabled: true, startMinutes: 1320, endMinutes: 420)` is quiet at 23:30 and 06:59 and not quiet at 07:00 or 21:59; `isEnabled: false` is never quiet; `airline(forCallsign: "N5955K")` is nil; `airline(forCallsign: "UAL1365")?.iata == "UA"`; `mph(knots: 100) == 115`.
- [ ] **Step 2:** `swift test` → the new tests FAIL.
- [ ] **Step 3:** Implement the five files.
- [ ] **Step 4:** `swift test` → all PASS.
- [ ] **Step 5:** Commit `feat: nearby selection, phase, formatting, quiet hours`.

### Task 4: Route, photo, elevation, and feed clients

**Files:**
- Create: `FlightKit/Sources/FlightKit/RouteDecoding.swift`, `FlightKit/Sources/FlightKit/Clients.swift`, fixtures `adsbdb-UAL1365.json`, `adsbdb-unknown.json`, `adsblol-UAL1365.json`, `planespotters-N27733.json`, `epqs.json`
- Test: `RouteDecodingTests.swift`, `ClientsTests.swift`

**Interfaces:**
- Consumes: Task 1 models, `FeedDecoding`, `Geo`
- Produces:
  - `typealias HTTPFetch = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)` plus `static let urlSession: HTTPFetch` (URLSession.shared)
  - `enum RouteDecoding { static func adsbdbRoute(from data: Data) -> Route?; static func adsbLolRoute(from data: Data) -> Route?; static func isPlausible(_ route: Route, for position: Coordinate, maxCrossTrackNM: Double = 100) -> Bool }`
  - `struct FeedClient: Sendable { let fetch: HTTPFetch; func aircraft(near: Coordinate, radiusNM: Int = 12) async throws -> [Aircraft] }`. Rounds coordinates to 2 decimals in the URL.
  - `struct RouteClient: Sendable { let fetch: HTTPFetch; func route(callsign: String, position: Coordinate) async throws -> Route? }`. Tries adsbdb, then adsb.lol, and returns the first route that passes `isPlausible` for `position`, else nil. A 404 or unknown response counts as no route. Makes no requests when the callsign doesn't match `^[A-Z]{3}[0-9]`.
  - `struct PhotoClient: Sendable { let fetch: HTTPFetch; let userAgent: String; func photo(registration: String) async throws -> AircraftPhoto? }`
  - `struct ElevationClient: Sendable { let fetch: HTTPFetch; func groundElevationFeet(at: Coordinate) async throws -> Double }`
  - `enum ClientError: Error, Equatable { case http(status: Int) }`, thrown for status codes other than 2xx/404.

- [ ] **Step 1:** Save the fixtures with curl from the URLs in Global Constraints (planespotters needs `-A "FlightOverheadDev/0.1 (+https://example.com)"`). Also write `adsbdb-unknown.json` as `{"response":"unknown callsign"}`. Save `adsblol-UAL1365.json` from `https://vrs-standing-data.adsb.lol/routes/UA/UAL1365.json`. Pin the UAL1365 fixtures to the verified contents: adsbdb DFW→EWR, adsb.lol SNA→EWR.
- [ ] **Step 2: Write failing tests:**
  - The adsbdb UAL1365 fixture → `airlineName == "United Airlines"`, `origin.iata == "DFW"`, `destination.iata == "EWR"`.
  - The adsb.lol UAL1365 fixture → `origin.iata == "SNA"`, `destination.iata == "EWR"`.
  - `RouteClient.route(callsign: "UAL1365", position: CLE)` with both fixtures stubbed → SNA→EWR. With adsb.lol returning 404 → nil.
  - The unknown fixture → nil.
  - `isPlausible` at CLE: false for DFW→EWR (~150 nm), true for SNA→EWR (~41 nm), false for LAX→SFO.
  - `FeedClient` builds the URL `https://opendata.adsb.fi/api/v2/lat/41.41/lon/-81.85/dist/12` from home `41.4123, -81.8498`. Assert this through a stub `HTTPFetch` that records the request.
  - `PhotoClient` sends the given `User-Agent` header and decodes the photographer `"Wolfgang Kaiser"`.
  - `RouteClient.route(callsign: "N5955K", position: CLE)` makes zero requests.
  - A 503 stub throws `ClientError.http(status: 503)`.
  - `ElevationClient` decodes 781.64.
- [ ] **Step 3:** `swift test` → FAIL.
- [ ] **Step 4:** Implement.
- [ ] **Step 5:** `swift test` → PASS.
- [ ] **Step 6:** Commit `feat: flight data clients`.

### Task 5: FlightTracker state machine

**Files:**
- Create: `FlightKit/Sources/FlightKit/FlightTracker.swift`
- Test: `FlightTrackerTests.swift`

**Interfaces:**
- Consumes: Tasks 1–4
- Produces:
  ```swift
  @MainActor @Observable final class FlightTracker {
    enum Status: Equatable { case idle, quiet, offline }
    struct Sighting: Equatable { let plane: NearbyPlane; var route: Route?; var photo: AircraftPhoto?; let phase: FlightPhase; let seenAt: Date }
    private(set) var current: Sighting?        // nil when nothing qualifies
    private(set) var lastSeen: Sighting?       // most recent non-nil current
    private(set) var status: Status
    var onNewPlane: (@MainActor (Sighting) -> Void)?   // once per hex per pass
    init(feed: FeedClient, routes: RouteClient, photos: PhotoClient, now: @escaping @Sendable () -> Date = Date.init)
    func configure(home: Home, criteria: NearbyCriteria, quietHours: QuietHours)
    func tick() async            // one poll cycle; testable
    func start()                 // loops tick() with nextDelay
    func stop()
    var nextDelay: Duration { get }  // 5s normally; after consecutive failures 10, 20, 60 (cap)
  }
  ```
- Behaviour:
  - During quiet hours, `tick()` sets `.quiet`, clears `current`, and makes no network calls.
  - On a feed error it sets `.offline` and keeps `lastSeen`.
  - Routes are cached per callsign (looked up with the position at first sighting) and photos per registration for the app's lifetime. Each is fetched at most once, after the plane first qualifies. `current` updates first, and the route and photo fill in after.
  - `onNewPlane` fires when a `hex` becomes `current` and hasn't been current in the last 2 minutes.
  - An emergency squawk (7500/7600/7700) needs no special handling here; the card reads it from `plane.aircraft.squawk`.

- [ ] **Step 1: Write failing tests** using stub `HTTPFetch` closures and an injected clock:
  - Two qualifying planes → `current` is the closer one.
  - A plane leaves range → `current == nil` and `lastSeen` is that plane.
  - Quiet hours → zero requests and status `.quiet`.
  - Feed 503 three times → `nextDelay` goes 10s, 20s, 60s; then success → 5s and `.idle`.
  - The same plane over 3 ticks → one `RouteClient` lookup and one `onNewPlane` call.
  - The plane is out for 3 minutes and then back → `onNewPlane` fires again.
  - A route lookup returning nil → `current.route == nil`.
- [ ] **Step 2:** `swift test` → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `swift test` → PASS. Coverage: `swift test --enable-code-coverage` shows ≥ 80% for FlightKit.
- [ ] **Step 5:** Commit `feat: FlightTracker polling state`.

### Task 6: App shell, menu bar, detail card

**Files:**
- Create: `project.yml`, `App/FlightOverheadApp.swift`, `App/StatusItemController.swift`, `App/FlightCardView.swift`, `App/AppSettings.swift`, `App/Info.plist`, `App/FlightOverhead.entitlements`

**Interfaces:**
- Consumes: `FlightTracker`, `Formatting`, `Lookups`, models
- Produces:
  - `enum MenuBarStyle: String, CaseIterable { case liveText, quietIcon, autoOpenCard }`
  - `@MainActor @Observable final class AppSettings`, backed by UserDefaults, with properties `home: Home?`, `style: MenuBarStyle`, `criteria: NearbyCriteria`, `quietHours: QuietHours`, `notificationsEnabled: Bool`, `launchAtLogin: Bool`, and defaults per Global Constraints
  - `AppConstants.userAgent: String`. **The value depends on open question 1.**

Notes the implementer cannot infer:
- `project.yml`:
  - macOS app target `FlightOverhead`, bundle id `com.andrikanich.FlightOverhead`, deployment target 15.0.
  - Local package dependency on `FlightKit`.
  - `INFOPLIST_FILE`, `LSUIElement: true`, `CODE_SIGN_ENTITLEMENTS`, `DEVELOPMENT_TEAM` read from the env var `FLIGHT_TEAM_ID`, `ENABLE_HARDENED_RUNTIME: YES`.
- Entitlements: `com.apple.security.app-sandbox`, `com.apple.security.network.client`.
- Use `NSStatusItem` + `NSPopover` (`behavior = .transient`), not `MenuBarExtra`, because the auto-open style must open and close the card programmatically. This deviates from the spec's `MenuBarExtra` mention, deliberately.
- Status item rendering:
  - **liveText:** SF Symbol `airplane` plus `Formatting.menuBarText` when `current != nil`. Otherwise the symbol alone.
  - **quietIcon:** the symbol is tinted `controlAccentColor` when `current != nil`. No text.
  - **autoOpenCard:** the symbol only. The popover opens when `onNewPlane` fires and closes 10 s after `current` becomes nil, unless the user opened it themselves.
  - **Offline:** the symbol at 40% alpha. **Quiet:** the symbol `moon.zzz`.
  - No animation in any style.
- Card (`FlightCardView`), top to bottom:
  - Photo (`AsyncImage`, 280 pt wide) with `"© {photographer}"` linking to `pageURL`.
  - Title: `"{airline name} {IATA flight number}"`. The airline name is `route.airlineName ?? Lookups.airline(forCallsign:)?.name`. Fall back to the flight label.
  - `typeDescription ?? typeCode`.
  - `"{origin city} ({IATA}) → {destination city} ({IATA})"`, or `route unknown`.
  - Phase text: `Arriving CLE` / `Departing CLE` / `Passing over`.
  - `"{n} ft above you · {d} mi away"`.
  - `"{mph} mph"`.
  - `"~{seats} seats (typical capacity)"` when known.
  - `"{registration} · built {year} ({age} yrs)"` when known.
  - Emergency squawk: a red banner `"Emergency squawk 7700"`, `7600 radio failure`, or `7500 hijack`.
  - When showing `lastSeen`, a header `"Last seen {relative time}"`.
  - Footer: gear button (opens Settings) and Quit.

- [ ] **Step 1:** Write `project.yml`, the plist and entitlements, then run `xcodegen generate` → `FlightOverhead.xcodeproj` is created.
- [ ] **Step 2:** Implement the app files. Wire `FlightTracker(feed:routes:photos:)` with `HTTPFetch.urlSession`, call `configure` from `AppSettings` on every change, and call `start()` at launch when `home != nil`. When `home == nil`, open Settings at launch.
- [ ] **Step 3:** `xcodebuild -project FlightOverhead.xcodeproj -scheme FlightOverhead -configuration Debug build -quiet` → no errors.
- [ ] **Step 4:** Manual check: run from Xcode with home set to `41.41, -81.85` in the debugger or the defaults. Within 10 s the menu bar shows live text, or the plain icon if the sky is empty. Clicking opens the card. There's no Dock icon.
- [ ] **Step 5:** Commit `feat: menu bar app shell and detail card`.

### Task 7: Settings, notifications, launch at login

**Files:**
- Create: `App/SettingsView.swift`, `App/Notifier.swift`
- Modify: `App/FlightOverheadApp.swift` (Settings scene, notifier wiring)

**Interfaces:**
- Consumes: `AppSettings`, `ElevationClient`, `FlightTracker.onNewPlane`
- Produces: `@MainActor final class Notifier { func requestAuthorizationIfNeeded() async -> Bool; func post(_ sighting: FlightTracker.Sighting) }`

Notes:
- **Location section:**
  - An address `TextField` geocoded with MapKit (`MKGeocodingRequest`, or `CLGeocoder` if it's unavailable at the deployment target).
  - A `Map` the user taps to drop or move a pin.
  - After the location is set, call `ElevationClient` once and show `"Ground elevation: 782 ft"` in an editable field.
  - Saving writes `AppSettings.home`.
- **Menu bar section:** style picker with the three cases and their descriptions from the spec.
- **Traffic section:**
  - Filter picker labelled `Airport traffic (below 10,000 ft)` / `Passing over (above 10,000 ft)` / `All traffic`.
  - Radius stepper from 0.5 to 5 mi in steps of 0.5.
- **Notifications:**
  - Toggle. Turning it on requests authorization with `[.alert]` only (no `.sound`).
  - Post one banner per `onNewPlane`. Title is the menu bar text without the ✈︎; body is the route or `route unknown`. `sound = nil`.
  - Suppress banners while the popover is open.
- **Quiet hours:** toggle plus two `DatePicker(.hourAndMinute)` fields.
- **Launch at login:** toggle backed by `SMAppService.mainApp.register()` / `unregister()`, showing the actual `status` on appear.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** `xcodebuild … build -quiet` → no errors.
- [ ] **Step 3:** Manual check:
  - Enter an address → the pin moves and the elevation fills in.
  - Switch styles → the menu bar changes on the next tick, with no animation.
  - Enable notifications → a silent banner on the next new plane.
  - Set quiet hours to cover now → the moon icon shows and the network log shows no requests.
- [ ] **Step 4:** Commit `feat: settings, silent notifications, launch at login`.

### Task 8: Signed release build and install

**Files:**
- Create: `scripts/release.sh`, `README.md` (build/run/release steps, data-source credits, personal non-commercial use note)

- [ ] **Step 1:** Write `scripts/release.sh` (`set -euo pipefail`). It requires `FLIGHT_TEAM_ID` and a notarytool keychain profile name in `FLIGHT_NOTARY_PROFILE`, and it:
  1. Runs `xcodegen generate`.
  2. Runs `xcodebuild archive -scheme FlightOverhead -archivePath build/FlightOverhead.xcarchive`.
  3. Runs `xcodebuild -exportArchive` with a Developer ID `ExportOptions.plist`, which the script generates.
  4. Zips the app and runs `xcrun notarytool submit --wait --keychain-profile "$FLIGHT_NOTARY_PROFILE"`.
  5. Runs `xcrun stapler staple`.
  6. Copies the app to `/Applications/FlightOverhead.app`.
- [ ] **Step 2:** Chris runs `FLIGHT_TEAM_ID=… FLIGHT_NOTARY_PROFILE=… scripts/release.sh`. Expected: `The staple and validate action worked!`, and `spctl -a -vv /Applications/FlightOverhead.app` reports `source=Notarized Developer ID`.
- [ ] **Step 3:** Manual end-to-end:
  - Launch from /Applications.
  - Enable launch at login and log out and back in → the app returns.
  - Watch one real CLE arrival: the live text appears, the card shows the route or `route unknown`, and no sound plays.
- [ ] **Step 4:** Commit `chore: release script and README`.

---

## Open questions for Chris

1. **Photo request identification.** planespotters.net rejects requests unless the `User-Agent` includes a contact URL or email. Which should it contain? Options: a URL you control, your email, or no photos.
2. **Notarization credentials.** Do you already have a `notarytool` keychain profile? If not, Task 8 needs you to run `xcrun notarytool store-credentials` once.
3. **GitHub remote.** Should this repo go on GitHub, private, so the work is backed up? It's local only right now.
