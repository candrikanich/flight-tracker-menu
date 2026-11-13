# Figma polish on the card

Chris passed along Figma's suggestions on 2026-11-13. Figma's overall verdict was to keep the layout and reduce competition for attention, with no new colors, cards or decoration.

## What, and my calls
1. **Map.** Figma asked for a local view by default. That is already the default ("Nearby"); the map spanning several states is the "Full route" setting, which is how the screenshot was taken.
   - In that mode a small "Flight route" label now sits above the map, so its purpose is clear.
   - The route framing margin goes from 15% to about 19% on each side, so the plane isn't pressed against the edge. The nearby framing is unchanged.
2. **Freshness.** Only half taken.
   - Stale: "Last known position · 6 min ago" becomes "Last seen 6 min ago".
   - Fresh: it stays "Nearby now" rather than Figma's "Updated just now". "Nearby now" says the plane is close right now, and that is the reason the card exists. Fresh and stale still read differently, which was a requirement from the start.
3. **Model names.** The feed capitalizes only the maker ("BOEING 737 MAX 8", "DE HAVILLAND DHC-6 Twin Otter"), so only those leading words are re-cased: "Boeing 737 MAX 8", "de Havilland DHC-6 Twin Otter". Designations like MAX and CRJ-900 stay. This applies on the card and in the Sky log.
4. **Bottom section.** The tally was already a headline ("57 planes over you today") over a detail line. The runway line now has a "Local traffic" label and extra space above it, so it doesn't read as a fact about the plane above.
5. **Stats.** The gap between columns goes from 8 to 14 pt and the labels from 11 to 10 pt. The values keep their size.

## Review
The opus code reviewer found one Important issue, fixed with a test that failed first:
- The re-casing broke initialism makers ("Atr", "Bae") and "Mc" names ("Mcdonnell"). Maker words of 3 letters or fewer now keep their capitals, and MC names become "McDonnell".

The reviewer measured the stats row: "Height above you" now fits at 10 pt without scaling (84 of 86.7 pt), where at 11 pt it was already being scaled down.

Deferred minors:
- In Full route mode the "Flight route" label appears only once the route lookup finishes, so the card grows by about 17 pt at that moment. The map already re-framed at that point; watch whether the jump is noticeable.
- VoiceOver still says "at last known position" on stale stats, while the screen now says "Last seen". Both read fine.
- Maker words with a hyphen ("BRITTEN-NORMAN") stay in capitals.
