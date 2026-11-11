import FlightKit
import UserNotifications

/// Silent banners only; the app never plays a sound.
@MainActor
final class Notifier {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    func post(_ sighting: FlightTracker.Sighting) {
        let content = UNMutableNotificationContent()
        content.title = Formatting.summary(sighting.plane, route: sighting.route)
        content.body = sighting.route.map { route in
            "\(route.origin.city ?? route.origin.icao) → \(route.destination.city ?? route.destination.icao)"
        } ?? "route unknown"
        content.sound = nil
        content.interruptionLevel = .passive
        let request = UNNotificationRequest(identifier: sighting.plane.aircraft.hex, content: content, trigger: nil)
        center.add(request)
    }
}
