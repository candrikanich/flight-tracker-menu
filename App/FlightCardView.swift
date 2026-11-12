import FlightKit
import SwiftUI

struct FlightCardView: View {
    let tracker: FlightTracker
    let openSettings: () -> Void
    let openSkyLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            TimelineView(.everyMinute) { context in
                TallyLine(tally: DailyTally(passes: tracker.skyLog.passes, on: context.date, calendar: .current))
            }
            Divider()
            HStack {
                Button("Settings…", systemImage: "gearshape", action: openSettings)
                Button("Sky log", systemImage: "clock.arrow.circlepath", action: openSkyLog)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
    }

    @ViewBuilder private var content: some View {
        if let sighting = tracker.current {
            SightingDetails(sighting: sighting, header: nil)
        } else if let sighting = tracker.lastSeen {
            TimelineView(.everyMinute) { context in
                SightingDetails(sighting: sighting, header: Formatting.lastSeen(sighting.seenAt, now: context.date))
            }
        } else {
            Text(emptyMessage).foregroundStyle(.secondary)
        }
    }

    private var emptyMessage: String {
        switch tracker.status {
        case .quiet: "Quiet hours. Planes will show again when they end."
        case .offline: "Can't reach the flight feed right now."
        case .idle: "No planes overhead yet."
        case .needsHome: "Set your home location in Settings, then click Save location."
        }
    }
}

/// Quiet by design: nothing at all until a plane has passed today.
private struct TallyLine: View {
    let tally: DailyTally

    var body: some View {
        if tally.count > 0 {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.tallyHeadline(count: tally.count))
                if let details = Formatting.tallyDetails(tally, calendar: .current) {
                    Text(details)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct SightingDetails: View {
    let sighting: FlightTracker.Sighting
    let header: String?

    private var aircraft: Aircraft { sighting.plane.aircraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let header {
                Text(header).font(.caption).foregroundStyle(.secondary)
            }
            if let emergency = emergencyText {
                Label(emergency, systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red, in: .rect(cornerRadius: 6))
            }
            Text(title).font(.title3.bold())
            if let type = aircraft.typeDescription ?? aircraft.typeCode {
                Text(type).foregroundStyle(.secondary)
            }
            Text(routeText)
            Text(phaseText).foregroundStyle(.secondary)
            Text("\(sighting.plane.heightAboveHomeFeet.formatted()) ft above you · \(milesText) mi away")
            if let mph = aircraft.groundSpeedKnots.flatMap(Formatting.mph(knots:)) {
                Text("\(mph) mph")
            }
            if let seats = aircraft.typeCode.flatMap(Lookups.typicalSeats(forTypeCode:)) {
                Text("~\(seats) seats (typical capacity)").foregroundStyle(.secondary)
            }
            if let registration = registrationText {
                Text(registration).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var title: String {
        Formatting.flightTitle(
            callsign: aircraft.callsign, registration: aircraft.registration, routeAirline: sighting.route?.airlineName
        )
    }

    private var routeText: String {
        guard let route = sighting.route else { return "route unknown" }
        return "\(Formatting.place(route.origin)) → \(Formatting.place(route.destination))"
    }

    private var phaseText: String { Formatting.phase(sighting.phase) }

    private var milesText: String {
        sighting.plane.distanceMiles.formatted(.number.precision(.fractionLength(1)))
    }

    private var registrationText: String? {
        guard let registration = aircraft.registration else { return nil }
        guard let year = aircraft.yearBuilt else { return registration }
        let age = Calendar.current.component(.year, from: .now) - year
        return "\(registration) · built \(year) (\(age) yrs)"
    }

    private var emergencyText: String? { Formatting.emergency(squawk: aircraft.squawk) }
}
