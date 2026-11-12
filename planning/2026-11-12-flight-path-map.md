# Flight path map (issue #6)

**Goal:** show where the plane overhead came from, where it's going, and its path past home.

**Approved by Chris:** "we can hit #6 now" on 2026-11-12, after build 6 checked out on device.

## Design
- **`Tracks` (FlightKit, pure, tested):**
  - **What it records:** positions for every aircraft in the feed, on every successful check, each with its time. A path therefore starts about 12 NM out, before the plane qualifies for the card. It uses no new data source and no extra requests.
  - **Repeats:** a repeated position (the feed repeating a quiet plane) isn't added.
  - **Gaps:** a plane missing from the feed for more than 90 s (longer than the slowest 60 s retry) starts a fresh path. It flew somewhere unseen, and joining the two would draw a line it never flew.
  - **Limits:** at most 360 points per plane. A plane is forgotten 30 minutes after it leaves the feed, except the plane the card still shows.
  - **Cut at a moment:** `path(for:through:)` stops at a given time. The card cuts at the sighting's time, so a stale card's path ends at its frozen plane icon even though the plane is still in the feed.
- **`MapFraming.region` (tested):** frames home, the plane and its path, with a little padding and never tighter than 3 miles.
- **Heading:** `Aircraft.trackDegrees` comes from adsb.fi's `track`. Without a heading the plane is a plain dot, not an arrow guessing its direction.
- **Map tile:**
  - A 150 pt, non-interactive MapKit tile under the stats row.
  - What the app saw shows as a solid blue line.
  - Home and the plane have markers, with no title labels. On a stale card the tile is dimmed.
  - Where the plane came from and where it's going stay in the card's route text.
- **Setting:** "Show a map in the card" in Settings › Menu bar, on by default.

## My calls on the issue's open questions
- **In the card, not a separate window:** a small fixed tile reads at a glance. It can be turned off for anyone who wants the compact card back.
- **Only the path near home, and no planned-route line:** the tile only draws what the app saw.
  - An origin-to-destination great circle across a tile a few miles wide would miss the tile entirely or contradict the vectors the plane is really flying. It would also come from the least reliable data (callsign route lookups).
  - Full flight history from adsb.lol trace data needs its terms and rate limits checked first, so it's left out.
- **Not interactive:** panning inside a popover fights scrolling and clicks, and the tile is for a glance.

## Not in this change
- **Paths for past passes in the Sky Log:** they'd need to be stored on disk with each pass.
- **Full flight history from a third-party source.**

## Review (pr-review-toolkit:code-reviewer, opus)
- **Fixed:**
  - **Stale path ran past the plane:** fixed by cutting the path at the sighting's time. Test `pathCanBeCutAtTheMomentItWasLastSeen`, red then green.
  - **A gap was bridged with a straight line:** fixed by starting a fresh path after 90 s. Test `planeBackAfterAGapStartsAFreshPath`, red then green.
  - **Annotation titles showed as text:** hidden.
  - **Route line misleading at this zoom:** dropped (see my calls above).
  - **Hierarchical `.secondary` styles may not resolve inside map content:** the home marker now uses a solid gray, and the route line that also used it is gone.
  - **VoiceOver label claimed a path that may not exist:** it now mentions the path only when there is one.
  - **`Tracks.==` ignored the update time:** `==` is now synthesized from the stored values.
- **Deferred minors:**
  - No tests yet for these: `track` values out of range, an offline or quiet check recording nothing, a stale path surviving a prune 30+ minutes later, and the `forgetAfter` boundary.
  - A stale card whose plane leaves for more than 90 s and comes back loses its path, because the fresh path starts after the sighting. This is rare and harmless: the tile shows home and the frozen icon.

## Unresolved questions
- The test harness couldn't load map tiles. To check on device:
  - the path line and the markers render;
  - the tile moves with the plane between checks.
