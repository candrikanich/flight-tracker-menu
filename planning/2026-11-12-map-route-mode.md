# Map: nearby or full route

**Asked by Chris** on 2026-11-12: "can we offer a map setting option (local or full-route)?"

## Design
- **Setting:** the "Show a map in the card" toggle becomes a picker, "Map in the card": Off / Nearby / Full route. A caption under it says what the choice shows.
  - It's stored as `MapStyle` in FlightKit.
  - The old switch carries over: on, or never set, becomes Nearby; off stays Off. This follows `NotificationScope(legacyEnabled:)`.
- **Nearby** is unchanged: home, the plane, and the path it flew while in range.
- **Full route:**
  - frames the origin, destination, the great-circle arc between them, and the plane (`MapFraming.routeRegion`);
  - draws the planned arc as a dashed gray line (`Geo.greatCircle`);
  - shows small gray dots labeled with the airport codes;
  - shows the flown path in solid blue, as on Nearby.
- **No route known:** full route falls back to Nearby, so the tile never shows an empty frame.

## My calls
- **Home marker in full route:** dropped. At that scale it sits under the plane.
- **The planned line:** shown only in full route. Nearby still leaves it off, because at a few miles across it cuts against the vectors the plane is flying. At trip scale the line is the point.
- **Arc framing:** the tile frames the arc itself, not just the two airports. A long trip bows toward the pole: CLE to London peaks above 53°N, north of both airports.
- **Tile height:** still 150 pt. A wider frame needs no more room to read.

- **Date line:** a route across it falls back to Nearby. The arc's longitudes wrap, so the frame would center on the wrong side of the world. Overflights from the East Coast to Asia do this.

## Not in this change
- Drawing routes across the date line properly, which would mean unwrapping longitudes and splitting the line.
- Tapping the map to switch modes.

## Review
pr-review-toolkit:code-reviewer (opus) confirmed the slerp math, the migration, and the macOS 14 MapKit APIs.
- **Fixed, Important:** my note that "nothing from CLE crosses the date line" was wrong, because the Passing over and All traffic filters show overflights. An IAD→HND flight would have produced a region over 360° wide, centered over Africa, and MapKit can reject such a region. That route now falls back to Nearby, and every framing span is clamped. The tests `aRouteAcrossTheDateLineIsNotFramed` and `framingNeverExceedsTheWholeGlobe` failed first.
- **Fixed, minor:** renamed `MapStyle` to `MapMode`, so it can't be confused with MapKit's `MapStyle`, which the tile already uses. Added `aShortHopKeepsTheMinimumSpan`, which passes on the existing code.
- **Deferred, minor:** with the default airport filter, the plane draws on top of CLE's dot and label. Check on device whether that looks wrong. If it does, hide the label of an airport within a few miles of the plane.

## Unresolved questions
- Map tiles don't render off-device, so the full-route look hasn't been seen yet. Check on device:
  - a long route (e.g. a London flight) reads well at 150 pt;
  - the airport labels don't collide on a short hop.
