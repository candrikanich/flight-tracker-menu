# Card refinements (Figma critique of build 6)

**Approved by Chris:** "lets do figma refinements, then #4" on 2026-11-12.

## What Figma said, and what changed
- **Too much is equally gray; darken the stat values.**
  - On a live card the values were already primary. The screenshot was a stale card, where they were muted on purpose.
  - Now the values stay primary on a stale card too, and the "old" signal moves into the wording (next two points).
- **Stale state should apply clearly to the numbers.**
  - The line above the card now reads "Last known position · 6 min ago" instead of "Last seen 6 min ago". If something other than an empty sky is the reason, it is still appended, e.g. "· Flight data unavailable".
  - On a stale card the height label is "Height above you" instead of "Above you".
  - VoiceOver already says ", when last seen" after each stale value; that's unchanged.
- **Don't repeat N158PH.** With no callsign, the registration is already the flight identity (`flightLabel`), so the aircraft line leaves it out: "Bombardier Challenger 350". With a callsign the tail number is still shown there, because it appears nowhere else.
- **Give the daily count emphasis.** "11 planes over you today" is now 13 pt medium. "Busiest around 3 PM" stays secondary.
- **No new decoration:** agreed; nothing added.

## My calls
- **"Height above you" wrapped to two lines** in its 90 pt column. Stat labels are now one line and may shrink to 85%, so the stale row is the same height as the live one.
- **Rule for leaving out the registration:** the registration is dropped when `flightLabel` (the flight identity) is exactly the registration. That covers no callsign and a light aircraft broadcasting its tail number. It is an exact match, not a substring match, so a registration that merely appears inside a callsign isn't hidden.
- **VoiceOver:** stale values are read with ", at last known position" (was ", when last seen"), matching the visible wording.

## Review (pr-review-toolkit:code-reviewer, opus)
- **Fixed:**
  - **Registration still repeated when the callsign is the tail number** (common for light aircraft). Test `aircraftLineSkipsTheRegistrationWhenItIsTheCallsign`, red then green.
  - **Two stale doc comments in FlightCardView:** updated.
  - **Spoken wording out of step with the visible wording:** updated, with a test.
- **Deferred minors:**
  - `Formatting.lastSeen` now has no production caller; only its own tests use it.
  - The original v1 plan (`docs/superpowers/plans/2026-11-11-flight-overhead.md`) still describes the "Last seen" header.
  - A foreign tail broadcast without its hyphen ("C-GABC" sent as "CGABC") still shows twice.

## Unresolved questions
- None. The live and stale renders were checked in light and dark in the harness.
