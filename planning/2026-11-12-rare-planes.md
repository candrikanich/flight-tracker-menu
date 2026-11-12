# Rare planes (issue #3)

**Goal:** a calm heads-up when something unusual passes over.

**Approved by Chris:** "go" on 2026-11-12. He left the issue's open questions to me.

## Design
- **FlightKit `Rarity.of(_:)`** (pure, tested) returns the single most pressing reason, so the badge stays one short label. In priority order:
  1. Emergency squawk (7500/7600/7700).
  2. Hand-curated notable types: 747 family and Dreamlifter, A380, Belugas, An-124/225, C-5, C-17, B-52, V-22, DC-3, Constellation.
  3. Military, from adsb.fi `dbFlags` bit 1, which is now decoded into `Aircraft.isMilitary`.
  4. Helicopter (ADS-B category A7).
  5. NASA, by callsign prefix or operator name.
  6. Vintage: built before 1960. Planes from the 1960s are still everyday light aircraft.
- **Notifications:** the on/off switch becomes `NotificationScope`: **Nothing / Rare planes only / Every plane overhead**.
  - Existing choices carry over: on becomes every plane, off stays off.
  - Banners stay silent. Rare ones are titled "Rare: Military", with the usual summary as the subtitle.
- **Card:** a small grey "Rare · Military" capsule above the flight title. An emergency doesn't get one, since it already has the red banner.

## My calls on the issue's open questions
- **Which categories:** all of the above, as one short list. It's easy to trim if something turns out to be common over Olmsted Township, such as medical helicopters.
- **Settings toggle:** folded into the notifications picker rather than a separate switch. "Rare planes only" is the calm option the issue was after.

## Not in this change
- **Widening the range for rare planes:** it changes which plane the card shows, so it's a separate decision.
- **Marking rare passes in the Sky Log:** it would need the reason stored on each pass.

## Unresolved questions
- None blocking.

## Review
- Fixed: a malformed `dbFlags` value would have dropped the whole plane. The field is now lossy, and a test that failed first covers it.
- Fixed: emergency banners no longer say "Rare:".
- Fixed: added the 747SP (B74S) and the older C-5 (C5) to the list.
- Deferred (minor): changing the picker twice while the system permission prompt is open could save the earlier choice. The old toggle had the same pattern.
