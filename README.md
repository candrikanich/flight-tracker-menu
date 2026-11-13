# Overflight

A macOS menu-bar app that tells you about the plane flying over your house. It was built for living under the approach path to Cleveland Hopkins (CLE).

When a plane comes into view, the menu bar shows something like `UA1365 → EWR · 0.4 mi · 2,100 ft`. Click it for the airline, aircraft type, route, arriving/departing, height above you, speed, typical seat count, and tail number and age. There are no sounds and no flashing.

## Layout

| Path | What it is |
|---|---|
| `FlightKit/` | Platform-independent Swift package with all of the logic (feeds, geometry, "which plane is overhead", formatting, quiet hours, polling). Reusable for a future iOS or home-hub version. |
| `App/` | The macOS app: status item, detail card, settings, and notifications. |
| `Xcode/project.yml` | XcodeGen spec. The `.xcodeproj` is generated and git-ignored. |
| `scripts/release.sh` | Signed, notarized build installed to `/Applications`. |
| `docs/superpowers/` | Design spec and implementation plan. |

## Develop

```sh
swift test --package-path FlightKit                        # 202 unit tests
FLIGHT_TEAM_ID=<team id> xcodegen --spec Xcode/project.yml
open Xcode/Overflight.xcodeproj                         # run the Overflight scheme
```

On first launch the Settings window opens. Set your home by address or by clicking the map, check the ground elevation, and click **Save location**.

## Release (one-time setup, then one command)

1. Create a **Developer ID Application** certificate: Xcode → Settings → Accounts → Manage Certificates → **+**.
2. Store notarization credentials once, using an [app-specific password](https://account.apple.com):
   ```sh
   xcrun notarytool store-credentials flight-notary --apple-id <apple-id> --team-id <team id>
   ```
3. Build, notarize, and install:
   ```sh
   FLIGHT_TEAM_ID=<team id> FLIGHT_NOTARY_PROFILE=flight-notary scripts/release.sh
   ```

## Data sources

All free and community-run. Used here for personal, non-commercial purposes. Re-check each source's terms before distributing the app.

- Live positions: [adsb.fi](https://adsb.fi) open data API
- Routes: [adsbdb](https://www.adsbdb.com) and [adsb.lol](https://adsb.lol) route data. Routes are checked against the plane's actual position, and anything that doesn't fit shows **route unknown**.
- Ground elevation: [USGS Elevation Point Query Service](https://apps.nationalmap.gov/epqs/)

Privacy: your home location is stored only on your Mac. Feed queries send coordinates rounded to about 1 km, and the one-time elevation lookup rounds to about 100 m. Address search goes through Apple Maps.
