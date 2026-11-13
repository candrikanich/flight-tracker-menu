# Runway history: "since when"

Chris approved the idea on 2026-11-13 ("build 1").

## What
The card's runway footer line says how long the current direction has held:
"CLE landing on runway 24 since 2:40 PM · arrivals over you". A change of direction becomes a small moment
without adding any motion or a new row.

## My calls
- **Only a switch we saw.**
  - `RunwayFlowWatch` records the time only when the call goes from one runway to the other.
  - The first call after launch shows no "since", because the app didn't see that flow begin.
  - The time is when the votes crossed over, which lags the real change by a few minutes. That's close enough for a glance.
- **Lulls don't erase it.** When too few planes agree, the line hides, as before. If the call comes back the same way, the switch time stands.
- **Long gaps do.**
  - After 2 hours without a call (`continuityGap`: overnight, or the Mac asleep), the switch time is dropped. The flow could have flipped and flipped back unseen.
  - Then the next call is treated like a first one.
- **Today only.** "since" shows only when the switch was on the same calendar day; "since 11:50 PM" the next morning would read wrong.
- **Not persisted.** A relaunch starts fresh. This follows the first rule: we didn't see it.

## Tests
There are 11 new tests in `RunwayFlowTests`. `expiredVotesAreDropped` was also tightened: it now makes a real call, then checks that the call clears.

## Review
The opus code reviewer raised two Important findings. Both are fixed, with tests that failed first:
- **The time ran late.**
  - The call flips only once the old runway's votes age out, so dating the switch by the flip put it up to about 20 minutes after the real change.
  - The switch is now dated by the first sighting of the earliest plane on the new runway. Each vote keeps a first-seen time, because an arrival shows up on many checks.
  - Tests: `theSwitchIsDatedByTheFirstPlaneOnTheNewRunway` and `aPlaneSeenOnManyChecksDatesFromItsFirstSighting`.
- **A brief false flip left a wrong time for hours.**
  - At night, or in a wind shift, a couple of odd planes can flip the call and then flip it back.
  - A switch now counts only when the previous call had held a full window (20 min); otherwise no time is shown.
  - Test: `aBriefFlipAndBackLeavesNoSince`.

`sinceIsHiddenWhenTheCallMovedOnBetweenChecks` was also added. It pins an existing guard, so it passed from the start.

**Deferred, minor:** the reviewer suggested "within the last 12 h" instead of "same calendar day". As it stands, a switch at 11:50 PM loses its time at midnight. I kept the calendar-day rule, because "since 11 PM" read the next morning is the more misleading case.
