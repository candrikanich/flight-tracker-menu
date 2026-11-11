import Foundation
import Testing
@testable import FlightKit

@Suite struct QuietHoursTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: hour, minute: minute))!
    }

    let overnight = QuietHours(isEnabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60)

    @Test func quietLateEvening() {
        #expect(overnight.isQuiet(at: at(23, 30), calendar: calendar))
    }

    @Test func quietJustBeforeEnd() {
        #expect(overnight.isQuiet(at: at(6, 59), calendar: calendar))
    }

    @Test func notQuietAtEnd() {
        #expect(!overnight.isQuiet(at: at(7, 0), calendar: calendar))
    }

    @Test func notQuietJustBeforeStart() {
        #expect(!overnight.isQuiet(at: at(21, 59), calendar: calendar))
    }

    @Test func sameDayWindow() {
        let afternoon = QuietHours(isEnabled: true, startMinutes: 13 * 60, endMinutes: 15 * 60)
        #expect(afternoon.isQuiet(at: at(14, 0), calendar: calendar))
        #expect(!afternoon.isQuiet(at: at(15, 0), calendar: calendar))
    }

    @Test func disabledIsNeverQuiet() {
        let off = QuietHours(isEnabled: false, startMinutes: 22 * 60, endMinutes: 7 * 60)
        #expect(!off.isQuiet(at: at(23, 30), calendar: calendar))
    }

    @Test func defaultsAreOffAndOvernight() {
        #expect(QuietHours.default == QuietHours(isEnabled: false, startMinutes: 1_320, endMinutes: 420))
    }
}
