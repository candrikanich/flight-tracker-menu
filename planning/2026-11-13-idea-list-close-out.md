# Closing out the idea list

Chris asked on 2026-11-13 to "close out the idea list". These are the last three ideas from the unused-data review. All of them use fields the adsb.fi feed already sends, so there are no new requests.

## Live sample (2026-11-13, 220 planes within 150 NM of CLE)
- `nav_altitude_mcp` (the autopilot's selected altitude): 72% of planes. It arrives in 16 ft steps, so 33,000 comes through as 33,024.
- `emergency`: 91%, and all of them were "none". Medical flights set "lifeguard".
- `ownOp` (the registered owner): 85%. Some owners are bank trustees, such as "BANK OF UTAH TRUSTEE" and "WILMINGTON TRUST CO TRUSTEE".

## What
- **Target altitude** on the status line: "Arriving CLE · descending to 6,000 ft". Without a route, the bare "Climbing" becomes "Climbing to 33,000 ft".
- **Medical flights:** the "Rare · Medical flight" badge. Notifications set to "Rare only" include them.
- **Owner:** "Registered to Battelle Memorial Institute" in the card's details.

## My calls
- **The target shows only while the plane is moving toward it:** at least 300 fpm (the same threshold as Climbing and Descending), with the target in the direction of motion and at least 1,000 ft away. Pilots preset the next altitude while still level; in the sample, a level SkyWest at 34,000 ft showed 28,000.
- **Rounded to the hundred,** to undo the 16 ft encoding.
- **Hidden on stale cards,** like distance to go.
- **"Descending to", not "Leveling off at",** which the review proposed. It says the direction too, and reads naturally after "Arriving CLE".
- **Medical ranks right after emergency squawks.** It says more about the flight than the aircraft type does: a medical helicopter shows "Medical flight", not "Helicopter".
- **The owner shows only for non-airline flights,** meaning there is no route airline and no airline callsign. Airline flights already lead with the airline, and their registered owner is often a leasing trust.
- **Trustees are left out.** A bank holding title isn't who flies the plane.
- **"Registered to", not "Owned by".** That is what the registry actually says.
- **Mixed case with acronyms kept:** words of three letters or fewer, or without vowels, stay in capitals (FSI, GLC, LLC, III), apart from a short list of real words (Inc, Co, Air…). "of", "and" and "the" go lowercase.
- **One PR for all three:** each is small, and they ship in the same build.

## Review
The opus code reviewer raised three Important findings. All are fixed, with tests that failed first:
- **Flight levels against GPS height.** Above 18,000 ft the selected altitude is a flight level, set against standard pressure, and that can sit 1,500 ft from GPS height at cruise. That would hide real climbs, or show a target the plane had nearly reached. Targets at or above 18,000 ft are now compared with pressure altitude (`aFlightLevelIsComparedWithPressureAltitude`). Below that, the target is set to local pressure, so GPS height stays the reference (`aLowTargetIsComparedWithGPSHeight`).
- **"Descending to 0 ft".** Some avionics send 0 when nothing is set. Targets under 1,000 ft are dropped (`badTargetAltitudeKeepsThePlane`).
- **People's names.** The live sample had private owners listed as "BATTS GREGORY W" and "STURT MICHAEL H, STURT DARLINE K", plus "CANCELLED/NOT ASSIGNED". The line now shows only owners whose name contains an organization word (LLC, Inc, Academy, Health, Airport…). Missing one only hides the line, which is the safe way to be wrong (`peopleAreLeftOut`).

I also took one minor: a name that already has its own casing ("NetJets Sales Inc") is kept as is.

**Deferred, minor:**
- The casing misses some names: "Mcdonald", "O'brien", "ST Louis" and "FLY High LLC".
- Abbreviated trustee forms such as "TRSTE" aren't caught, if the registry uses them.
- Cleveland's hospital helicopters could set the medical "lifeguard" status often, which would mean frequent "Rare only" notifications. I'll watch for it on device; if it gets noisy, medical flights can stay a badge without notifying.
