import FlightKit
import SwiftUI

struct SkyLogView: View {
    let tracker: FlightTracker

    var body: some View {
        // Re-renders each minute so "Today" becomes "Yesterday" after midnight.
        TimelineView(.everyMinute) { context in
            let days = tracker.skyLog.days(calendar: .current)
            if days.isEmpty {
                ContentUnavailableView(
                    "Nothing has passed over yet",
                    systemImage: "airplane",
                    description: Text("Planes the card shows are listed here as they fly by.")
                )
            } else {
                List {
                    ForEach(days, id: \.day) { day in
                        Section(Formatting.dayTitle(day.day, now: context.date, calendar: .current)) {
                            ForEach(day.passes) { PassRow(pass: $0) }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Keeps the last 30 days. Stays on this Mac.")
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }
        .frame(width: 440, height: 540)
    }
}

private struct PassRow: View {
    let pass: Pass
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            details
        } label: {
            summary
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(pass.firstSeen, format: .dateTime.hour().minute())
                .monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.flightTitle(
                    callsign: pass.callsign, registration: pass.registration, routeAirline: pass.route?.airlineName
                )).bold()
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(closest) mi · \(pass.lowestHeightFeet.formatted()) ft")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .onTapGesture { expanded.toggle() }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let emergency = Formatting.emergency(squawk: pass.squawk) {
                Label(emergency, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
            if let route = pass.route {
                Text("\(Formatting.place(route.origin)) → \(Formatting.place(route.destination))")
            }
            Text(Formatting.phase(pass.phase))
            if let operatorName = pass.operatorName { Text(operatorName) }
            if let registration = pass.registration { Text(registration) }
            Text("In view \(pass.firstSeen.formatted(date: .omitted, time: .shortened))"
                 + "–\(pass.lastSeen.formatted(date: .omitted, time: .shortened))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.leading, 74)
    }

    private var subtitle: String {
        let type = pass.typeDescription ?? pass.typeCode
        let route = pass.route.map { route in
            "\(route.origin.iata ?? route.origin.icao) → \(route.destination.iata ?? route.destination.icao)"
        }
        return [type, route].compactMap(\.self).joined(separator: " · ")
    }

    private var closest: String {
        pass.closestMiles.formatted(.number.precision(.fractionLength(1)))
    }
}
