# Runway direction (issue #4)

**Goal:** say which way CLE is landing, so a busy or quiet day over the house makes sense.

**Approved by Chris:** "lets do figma refinements, then #4" on 2026-11-12.

## Design
- **`RunwayFlowWatch` (FlightKit, pure, tested):**
  - Fed every aircraft in the feed on each successful check. It uses no new data source and no extra requests.
  - **Which planes count:** a plane counts toward a runway when all of these hold:
    - airborne at 4,000 ft MSL or lower (about 3,200 ft above the field);
    - within 8 miles of CLE;
    - climbing or descending at 300 fpm or more (the threshold `Phase` already uses);
    - tracking within 30° of 052° (runway 6) or 232° (runway 24) true;
    - within 1.5 NM of the extended runway line, at the end that fits: an arrival still short of the field, a departure already past it (1 NM of leeway, since the airport point is mid-field). This keeps out downwind legs and departures turning back.
  - **Arrivals and departures both count**, because both go into the wind.
  - **Calling it:** each plane keeps one vote (its latest), and votes expire after 20 minutes. A flow is called only with at least 2 planes and 75% agreement; otherwise nothing is shown.
- **`overHome`:** decides which side of the field home is on, along the extended runway line.
  - Southwest of the field and landing on 6: arrivals over you. Landing on 24: departures over you.
  - Northeast of the field: the reverse.
  - More than 1.5 NM to the side of the line, or more than 12 NM along it: neither is claimed.
- **Card:** "CLE landing on runway 6 · arrivals over you" in secondary 12 pt under the daily count. It shows in both the plane and empty states, because it's most useful on a quiet day.

## My calls on the issue's open questions
- **Card only, no menu-bar hint:** the icon stays calm. A runway hint there would change several times a day and mean little without the words.
- **No METAR wind (the optional idea):** the planes themselves are the answer, and wind data would be a new source to maintain. Predicting a flow change can come later if it turns out to be wanted.
- **Runway numbers without L/C/R:** the planes say the direction, not which parallel.
- **Burke Lakefront traffic** (runways 6/24, about 11 mi northeast, almost on CLE's runway 6 line) is treated as agreeing: the same wind drives both fields. Only its runway 6 arrivals over downtown fall inside the 8-mile circle.

## Not in this change
- A flow history ("landing on 24 since 2 PM").
- Using wind to predict a change.

## Unresolved questions
- The runway headings (052°/232° true) come from the magnetic headings and about 8° west variation, not from survey data. The 30° tolerance makes that error harmless.
- I couldn't check live: when tested, CLE had no low traffic in the air. On device, confirm the line appears during a busy hour and names the runway you can see planes using.

## Review
pr-review-toolkit:code-reviewer (opus) confirmed the overHome geometry and found no concurrency issues.
- **Fixed, Important:** planes voted with no check on where they were, so two arrivals on a downwind leg could call the wrong runway, and a departure turning back could flip its vote for 20 minutes. Votes now need the runway-line gate above. The tests `planesOffToTheSideOfTheRunwayLineDoNotVote` and `aDepartureTurningBackKeepsItsVote` failed first.
- **Fixed, gaps:** added tests for 3 of 4 agreeing, the 12 NM limit along the line, and pruning of expired votes. They pass on the existing code. Added a comment that the 8-mile circle relies on the feed's 12 NM radius around home.
- **Fixed, docs:** BKL is about 11 mi from CLE, not 8.
- **Fixed after review:** helicopters (category A7) no longer vote. They fly their own approaches, so one on the runway line is not evidence (`helicoptersDoNotVote`).
- **Deferred, minor:** in calm wind, BKL light aircraft could use 6 while CLE uses its calm-wind runway. That's rare, and filtering by category would fix it.
