# Trip progress and data credits

Approved by Chris on 2026-11-13, from the unused-data review. Distance to go was the top pick. City names were the second pick, but they had already shipped: the card headline is `routeHeadline`, "Newark → Cleveland".

## What
- **Distance to go** on the card's codes line: "EWR → CLE · 350 mi to go · about halfway". It uses the route and position the app already has, with no new requests.
- **Data sources** section in Settings.
  - adsb.fi's open-data terms say "You must cite adsb.fi and include a link to our home page". The app didn't do that before.
  - Courtesy credits for adsbdb, VRS standing data via adsb.lol, USGS, and Apple Maps.

## My calls
- **Straight-line miles to the destination, rounded to tens,** so the number holds still between checks. The flown path is a little longer.
- **Hidden under 25 mi.** The status line already says "Arriving CLE", and a countdown in the last miles would twitch.
- **Words only at two points.** "about halfway" from 40% to 60% of the trip, by along-track distance, and "nearly there" from 85%. Elsewhere it's just the number.
- **Hidden on stale cards.** A frozen countdown would read as live; the card drops anything that looks live once it is stale.

## Licensing context (2026-11-13 research)
- adsb.fi open data is personal, non-commercial use only. A paid App Store release needs a different live feed, or written permission.
- adsbdb's route data may not be republished without David J Taylor's permission. The VRS standing data is CC0.
- USGS data is public domain.

## Review
The opus code reviewer raised two Important findings. Both are fixed, with tests that failed first:
- **Stale cards showed a frozen countdown.** The card now passes no position when stale, and the line is just the codes (`noPositionMeansJustTheCodes`).
- **VoiceOver read "right arrow" and "m-i".** The line now has a spoken form, "EWR to CLE, 350 miles to go, about halfway" (`voiceOverHearsWordsNotSymbols`). Written and spoken forms share one calculation.

I also added edge-case tests: past the destination (the miles still count back from the plane) and a zero-length route (nothing shown). I corrected the floor's comment: "Arriving CLE" comes from the destination, not the distance.

**Deferred, minor:**
- "nearly there" is purely fractional. On a London to Cleveland flight it appears about 500 mi out. Over Cleveland, long-haul overflights are usually past 85% only within a few hundred miles of somewhere like Chicago, so it reads fine.
- The 0.4, 0.6 and 0.85 boundaries, off-track positions, and non-equatorial geometry have no tests of their own. Geo's along-track math is covered elsewhere.
