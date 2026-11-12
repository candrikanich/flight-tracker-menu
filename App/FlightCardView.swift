import FlightKit
import SwiftUI

struct FlightCardView: View {
    let tracker: FlightTracker
    let settings: AppSettings
    let openSettings: () -> Void
    let openSkyLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Divider().padding(.vertical, 12)
            TimelineView(.everyMinute) { context in
                TallyLine(tally: DailyTally(passes: tracker.skyLog.passes, on: context.date, calendar: .current))
            }
            HStack(spacing: 12) {
                Button("Settings…", systemImage: "gearshape", action: openSettings)
                Button("Sky log", systemImage: "clock.arrow.circlepath", action: openSkyLog)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            .buttonStyle(.borderless)
            .padding(.top, 12)
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder private var content: some View {
        if let sighting = tracker.current ?? tracker.lastSeen {
            let isStale = tracker.current == nil
            TimelineView(.everyMinute) { context in
                SightingDetails(
                    sighting: sighting,
                    freshness: Formatting.freshness(
                        seenAt: sighting.seenAt, isCurrent: !isStale, status: tracker.status, now: context.date
                    ),
                    isStale: isStale,
                    mapHome: settings.showsMap ? settings.home?.coordinate : nil,
                    path: tracker.tracks.path(for: sighting.plane.aircraft.hex, through: sighting.seenAt)
                )
            }
        } else {
            let state = Formatting.emptyState(tracker.status)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.title).font(.system(size: 13, weight: .medium))
                if let detail = state.detail {
                    Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Quiet by design: nothing at all until a plane has passed today.
private struct TallyLine: View {
    let tally: DailyTally

    var body: some View {
        if tally.count > 0 {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.tallyHeadline(count: tally.count)).foregroundStyle(.primary)
                if let details = Formatting.tallyDetails(tally, calendar: .current) {
                    Text(details).foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 12))
        }
    }
}

private struct SightingDetails: View {
    let sighting: FlightTracker.Sighting
    /// "Nearby now" or "Last seen 2 min ago": words, not a colored dot, so fresh and stale can't be confused.
    let freshness: String
    /// A stale card keeps its facts but drops anything that looks live: no red banner, muted numbers.
    let isStale: Bool
    /// nil hides the map: turned off in Settings, or no home to put on it.
    let mapHome: Coordinate?
    let path: [Coordinate]

    private var aircraft: Aircraft { sighting.plane.aircraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(freshness)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if let emergency = Formatting.emergency(squawk: aircraft.squawk), isStale {
                    Label(emergency, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if let emergency = Formatting.emergency(squawk: aircraft.squawk) {
                    Label(emergency, systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red, in: .rect(cornerRadius: 6))
                }
                if let rare = rareText {
                    Label(rare, systemImage: "sparkles")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.quaternary, in: .capsule)
                }
            }
            heading
            StatsRow(stats: Formatting.stats(sighting.plane), isStale: isStale)
            if let mapHome {
                FlightMapView(home: mapHome, aircraft: aircraft, path: path, route: sighting.route)
                    .opacity(isStale ? 0.6 : 1)
            }
            details
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Without a route the flight identity becomes the headline, so the card never leads with a gap.
    @ViewBuilder private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let route = sighting.route {
                Text(Formatting.routeHeadline(route)).font(.system(size: 20, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(Formatting.routeCodes(route)).font(.system(size: 12)).foregroundStyle(.secondary)
                Text(identity).font(.system(size: 13, weight: .medium)).padding(.top, 2)
            } else {
                Text(identity).font(.system(size: 20, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Route unavailable").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if let status = Formatting.status(sighting.phase, hasRoute: sighting.route != nil) {
                Text(status).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var details: some View {
        let lines = [
            Formatting.aircraftLine(aircraft),
            aircraft.yearBuilt.map {
                Formatting.builtLine(year: $0, currentYear: Calendar.current.component(.year, from: .now))
            },
            Formatting.seatsLine(typeCode: aircraft.typeCode),
        ].compactMap(\.self)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { Text($0) }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
    }

    private var identity: String {
        Formatting.flightIdentity(
            callsign: aircraft.callsign, registration: aircraft.registration, routeAirline: sighting.route?.airlineName
        )
    }

    /// An emergency already has its own red banner, so it doesn't get a second badge.
    private var rareText: String? {
        switch Rarity.of(aircraft) {
        case nil, .emergency: nil
        case let rarity?: "Rare · \(Formatting.rarity(rarity))"
        }
    }
}

/// Equal columns with tabular figures, so the row doesn't shift as the numbers change each poll.
private struct StatsRow: View {
    let stats: [Formatting.Stat]
    let isStale: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(stats, id: \.label) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.value)
                        .font(.system(size: 19, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isStale ? .secondary : .primary)
                    Text(stat.label).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stat.spokenLabel(isStale: isStale))
            }
        }
    }
}
