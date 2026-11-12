# Daily tally (issue #2)

**Goal:** a calm line on the card, e.g. "23 planes over you today", with the busiest hour and the most common airline.

**Approved by Chris:** "go" on 2026-11-12. He left the issue's open questions to me.

## Design
- **No new storage.** The tally comes from the sky log (#5), which already counts each pass once, keeps 30 days, and stays on this Mac.
- **FlightKit `DailyTally`** (pure, tested):
  - It counts the passes that *started* on the given day, the same rule the sky log uses for grouping.
  - `busiestHour` and `topAirline` are set only when one value clearly leads with at least 2. A tie or a one-off returns nil, so the card never overstates.
  - The airline name prefers the callsign lookup over the route source's name, so one airline isn't split across two spellings.
- **Formatting:** `tallyHeadline(count:)` gives "1 plane / 23 planes over you today". `tallyDetails` gives "Busiest around 6 PM · Mostly United Airlines", with a narrow no-break space before PM, as Foundation formats it.
- **Card:** a caption below the plane details, refreshed every minute so it resets after local midnight. It's hidden while today's count is 0. There are no badges or notifications.

## My calls on the issue's open questions
- **Today only, no 7-day sparkline:** it keeps the card calm, and the Sky Log already shows earlier days.
- **Counts the planes the card showed** (those that match the traffic filter): it's the same set as the sky log, so the two always agree.

## Unresolved questions
- None blocking. A per-day count in the Sky Log's section headers would be cheap later.

## Review
- Fixed: a doc comment ended up above the new functions instead of `dayTitle`.
- Deferred (minor): the night clocks fall back, 1–2 AM happens twice and is counted as two hours. At worst the busiest hour is missing or shows as "1 AM". It never gives a wrong count.
