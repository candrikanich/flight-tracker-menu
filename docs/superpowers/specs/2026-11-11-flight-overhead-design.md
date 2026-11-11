# Flight Overhead — Design

Date: 2026-11-11
Status: Draft, awaiting approval

## Intent

Chris lives under the approach/departure path of Cleveland Hopkins International (CLE). Planes pass low over the house all day. He wants to glance at his Mac and know *what that plane is* — mostly out of curiosity about where it's coming from and going to — without buying a dedicated device (the commercial "Flight Wall" product inspired the idea).

The first version is a personal macOS menu-bar app running on Chris's own Mac. Selling it on the App Store and a version for Apple's upcoming home hub ("Home View", rumored to be CarPlay-like) are possible later, and the design should not paint those into a corner — but neither is a v1 goal.

## Goals (v1)

- Show the plane currently near/over the house, live, in the macOS menu bar.
- Answer: where from, where to, airline, aircraft type, how high above the house, how fast.
- Be calm: glanceable, never noisy.
- Use free data sources only.

## Non-goals (v1)

- App Store distribution, payments, licensing compliance for commercial use.
- Home View / iOS / widgets.
- Historical logs, statistics, maps, or flight tracking beyond "the plane near me now".
- Real passenger counts (no public source exists).

## Anti-goals (failure even if it "works")

- **Sounds.** No audio, ever, by default.
- **Excessive flashing or animation.** Text appears and disappears; nothing pulses or blinks. CLE traffic can pass every few minutes; the app must stay pleasant under that load.
- Showing a guessed route as fact. If the route is unknown, say "route unknown".

## User experience

### Menu bar (default style: Live Text)

- Idle: a small static ✈︎ icon.
- When a plane qualifies (see "What counts as nearby"), the item expands to live text, e.g. `✈︎ UA1234 → DEN · 0.4 mi · 2,100 ft`, updating as the plane moves.
- When it leaves range, the text disappears and the icon returns to idle. No animation on either transition.
- If several planes qualify, show the closest one; when it leaves, the next-closest takes over. No stacking, no queue of alerts.

### Click → detail card (popover)

Opening the menu item shows a card for the current plane (or the most recent one, labelled "last seen", if none is near now):

- Airline name and flight number
- Aircraft type (e.g. "Boeing 737-800")
- Origin → destination (airport names + codes), or "route unknown"
- Arriving / departing CLE / passing over (derived from altitude trend and route)
- Height above the house (ft), horizontal distance (mi)
- Ground speed (mph)
- Seat capacity estimate by type, clearly labelled as typical capacity (e.g. "~166 seats")
- Photo of that specific airframe, with photographer credit
- Registration (tail number) and airframe age when available
- Emergency squawk (7500/7600/7700) shown prominently on the card when present

### Settings

- **Home location:** entered once by address or by dropping a pin; stored locally only.
- **Menu bar style:** Live Text (default) · Quiet icon (icon changes color only, no pulse) · Auto-open card (card opens as the plane passes and closes after).
- **Traffic filter:** Airport traffic (below 10,000 ft, default) · Passing over (10,000 ft and above) · All.
- **Range:** adjustable horizontal radius for low traffic (default 1.5 mi).
- **Notifications:** off by default; when on, silent banners only, one per plane. Any finer filtering is left to the builder's judgment (keep it small).
- **Quiet hours:** optional schedule during which the menu bar stays idle and no notifications fire. Off by default.
- **Launch at login.**

### What counts as "nearby"

- Low traffic (< 10,000 ft): within the user's radius (default 1.5 mi horizontal).
- High traffic (≥ 10,000 ft): the radius widens with altitude so a jet at cruise (~35,000 ft) that's visible from the yard still qualifies. Builder picks the formula (e.g. a minimum elevation angle above the horizon); tune so cruise traffic visibly "passing over" qualifies but distant traffic near the horizon doesn't.
- Height above the house = reported altitude minus the house's ground elevation (CLE area is roughly 750 ft MSL; look up elevation for the entered location).

## Data (free sources only)

- **Live positions:** a free community ADS-B feed queried by point + radius (candidates: adsb.lol, airplanes.live). Provides callsign, altitude, ground speed, vertical rate, squawk, type, registration.
- **Routes:** free community route lookup by callsign (e.g. adsb.lol's route lookup). May be wrong or missing → "route unknown". If unknowns become a real problem, revisit a paid source (e.g. FlightAware AeroAPI) later.
- **Airline names:** from the ICAO callsign prefix.
- **Seat capacity:** a small bundled table of typical seats per aircraft type.
- **Photos:** planespotters.net photo API by registration, honoring its attribution requirements.
- Poll at a respectful interval for the feed (on the order of every 5–10 s while running) and back off on errors. Personal, non-commercial use only — fine for v1; licensing must be re-checked before any sale.

## Architecture constraints

- Swift, SwiftUI, macOS menu-bar app (`MenuBarExtra`).
- The Mac is a desktop that stays home: v1 uses only the fixed home location and requests no Location Services permission. A future version (laptop/away handling) will need it.
- Signed with Chris's paid Apple Developer account (Developer ID, notarized) and installed in /Applications, so launch at login and notifications behave reliably. Enable the App Sandbox with the outgoing-network entitlement from the start, to keep the App Store path open.
- Keep flight logic (fetching, filtering, "which plane is nearby", formatting) in a platform-independent Swift package, separate from the Mac UI, so a future Home View/iOS/widget target can reuse it.
- The data source sits behind a single seam so a paid feed can replace the free one later.
- No backend server; the app talks to the feeds directly.
- Location stored on-device only. *(Builder-check call)* The home location leaves the Mac only for: (a) address lookup via Apple's MapKit geocoder, (b) a one-time ground-elevation lookup (e.g. USGS), shown and editable in settings, and (c) feed queries using coordinates rounded to ~1 km with a correspondingly wider radius, with exact distance filtering done on-device. Routes and photos are looked up by callsign/registration only.

## Left to the builder

- *(Builder-check call)* A free API key for the feed is acceptable (store it in the Keychain). If every viable free feed requires running an ADS-B receiver or paying, stop and ask Chris.

- Exact free feed choice after checking current API availability and rate limits.
- Polling interval, caching, and error/offline display (keep it quiet: e.g. a dimmed icon).
- Visual design of the card and settings window, within macOS conventions.
- Elevation lookup method.
- The altitude-based visibility formula and its tuning.
- Test strategy (the pure flight-logic package should be thoroughly unit tested).

## Later (explicitly out of v1)

- App Store release (re-check data/photo licensing, possibly paid feeds).
- Home View version once hardware/SDK are available.
- A macOS widget as a secondary, slower-refreshing view.
- Location permission and away-from-home behavior for laptops.
