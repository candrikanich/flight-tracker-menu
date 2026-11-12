import FlightKit
import UserNotifications

/// Silent banners only; the app never plays a sound.
@MainActor
final class Notifier {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    func post(_ sighting: FlightTracker.Sighting, rarity: Rarity?) {
        let content = UNMutableNotificationContent()
        let summary = Formatting.summary(sighting.plane, route: sighting.route)
        if let rarity {
            let label = Formatting.rarity(rarity)
            // "Rare" would understate an emergency.
            if case .emergency = rarity { content.title = label } else { content.title = "Rare: \(label)" }
            content.subtitle = summary
        } else {
            content.title = summary
        }
        content.body = sighting.route.map { route in
            "\(route.origin.city ?? route.origin.icao) → \(route.destination.city ?? route.destination.icao)"
        } ?? "route unknown"
        content.sound = nil
        content.interruptionLevel = .passive
        let request = UNNotificationRequest(identifier: sighting.plane.aircraft.hex, content: content, trigger: nil)
        center.add(request)
    }
}
