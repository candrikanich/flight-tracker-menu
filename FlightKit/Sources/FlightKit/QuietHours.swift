import Foundation

public struct QuietHours: Sendable, Codable, Equatable {
    public static let `default` = QuietHours(isEnabled: false, startMinutes: 22 * 60, endMinutes: 7 * 60)

    public var isEnabled: Bool
    /// Minutes after local midnight.
    public var startMinutes: Int
    public var endMinutes: Int

    public init(isEnabled: Bool, startMinutes: Int, endMinutes: Int) {
        self.isEnabled = isEnabled
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    public func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, startMinutes != endMinutes else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return startMinutes < endMinutes
            ? (startMinutes..<endMinutes).contains(now)
            : now >= startMinutes || now < endMinutes
    }
}
