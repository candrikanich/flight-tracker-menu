import FlightKit
import Foundation
import Observation

enum MenuBarStyle: String, CaseIterable, Codable, Identifiable {
    case liveText, quietIcon, autoOpenCard

    var id: Self { self }

    var title: String {
        switch self {
        case .liveText: "Live text"
        case .quietIcon: "Quiet icon"
        case .autoOpenCard: "Card opens on its own"
        }
    }

    var detail: String {
        switch self {
        case .liveText: "Flight, destination, distance and height appear next to the icon while a plane is near."
        case .quietIcon: "The icon changes color while a plane is near. No text."
        case .autoOpenCard: "The detail card opens as a plane passes and closes after it's gone."
        }
    }
}

/// Every user setting, persisted to UserDefaults as it changes.
@MainActor
@Observable
final class AppSettings {
    var home: Home? { didSet { save(home, for: .home) } }
    var style: MenuBarStyle { didSet { save(style, for: .style) } }
    var criteria: NearbyCriteria { didSet { save(criteria, for: .criteria) } }
    var quietHours: QuietHours { didSet { save(quietHours, for: .quietHours) } }
    var notificationScope: NotificationScope { didSet { save(notificationScope, for: .notificationScope) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        home = Self.load(Home.self, .home, from: defaults)
        style = Self.load(MenuBarStyle.self, .style, from: defaults) ?? .liveText
        criteria = Self.load(NearbyCriteria.self, .criteria, from: defaults) ?? NearbyCriteria()
        quietHours = Self.load(QuietHours.self, .quietHours, from: defaults) ?? .default
        notificationScope = Self.load(NotificationScope.self, .notificationScope, from: defaults)
            ?? NotificationScope(legacyEnabled: Self.load(Bool.self, .notificationsEnabled, from: defaults))
    }

    private enum Key: String {
        case home, style, criteria, quietHours, notificationScope
        /// The old on/off switch: read once to carry it over, never written again.
        case notificationsEnabled
    }

    private func save<T: Encodable>(_ value: T, for key: Key) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key.rawValue)
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: Key, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key.rawValue).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
