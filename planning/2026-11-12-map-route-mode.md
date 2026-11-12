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

## Not in this change
- Routes that cross the date line, which would frame badly. Nothing from CLE does that.
- Tapping the map to switch modes.

## Unresolved questions
- Map tiles don't render off-device, so the full-route look hasn't been seen yet. Check on device:
  - a long route (e.g. a London flight) reads well at 150 pt;
  - the airport labels don't collide on a short hop.
