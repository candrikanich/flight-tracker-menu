# Card redesign (Figma handoff)

**Goal:** make the popover readable at a glance: route first, then who is flying it, then three numbers.

**Source:** the Figma spec "Overhead aircraft — menu bar app design handoff" (file GyRgAcJso3TyxkIGVA75qO, node 5:2).
**Approved by Chris:** "go" on 2026-11-12, ahead of #6 (map).

## What changed
- **Card order:**
  1. Freshness
  2. Emergency banner or rare badge
  3. Route headline ("Chicago → Cleveland") with the codes line under it
  4. Identity ("Southwest Airlines · WN4479")
  5. Status
  6. Stats row: Above you, Distance, Speed
  7. Aircraft details
  8. Divider
  9. Daily summary
  10. Footer
- **Width:** 320 pt, with 16 pt padding.
- **Fonts:** sizes from the spec's type table; tabular digits for the stats.
- **No route:** the identity becomes the headline, with "Route unavailable" under it.
- **Missing speed:** shows "—" with an accessible "Speed unavailable". Each stat column reads as one sentence, such as "1,885 feet above you".
- **Status line:** hidden when it would only show the tracker's fallback guess, which is "Passing over" with no route.
- **Empty states:**
  - New `FlightTracker.Status.loading` until the first check answers. It shows "Looking for nearby flights…".
  - "No planes nearby" is distinct from "Flight data unavailable".
- **Stale card:** "Last seen 3 min ago · Flight data unavailable" when the feed drops while showing the last plane.
- **Copy:** the notification body says "Route unavailable" instead of "route unknown".
- **Code:** the new copy is in `CardFormatting.swift`, as pure functions that are tested.

## My calls
- **Airline names:** kept full ("Southwest Airlines") rather than adding a short-name table that could drift.
- **"Nearby now" as the live label:** the card only shows a plane that passed the nearby rules on the latest successful check, so this is the recency rule the spec asks for. I didn't use "Overhead now" because a plane 1.4 mi away isn't overhead.
- **"Speed":** the value is ground speed, which the spec allows.
- **Rare badge and emergency banner:** kept, just above the route.
- **Type names:** shown as the feed sends them ("BOEING 737-700"). Title-casing would mangle names like "McDonnell Douglas".

## Not in this change
- Map (#6), aircraft photos, and expandable details. The spec defers all three.

## Review
- **Fixed:** a stale card looked live. It now has muted numbers and no red banner; an old emergency shows as a neutral line. VoiceOver reads each stat with "when last seen". Covered by tests that failed first.
- **Fixed:** the stale card now says why nothing is live for quiet hours and no home location, not only for a feed outage (`Formatting.freshness`, tested).
- **Fixed (minor):** the route headline is marked as a header. The card and the Sky Log share one airline rule. Wrapped a line that was over 120 characters.
- **Deferred (minor):** no test for distances that round near zero.

## Unresolved questions
- None blocking. Check on device: popover height with a long route, and VoiceOver on the stats row.
