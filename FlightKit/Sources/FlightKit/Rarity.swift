import Foundation

/// Why a plane is worth a heads-up. Only the most pressing reason is kept, so the badge stays one short label.
public enum Rarity: Sendable, Equatable {
    case emergency(String)
    case notableType(String)
    case military
    case helicopter
    case specialOperator(String)
    case vintage(year: Int)

    /// Before this, a plane is a warbird or a museum piece; 1960s light aircraft are still everyday traffic.
    static let vintageBefore = 1960

    /// Hand-picked and short on purpose: rare over Cleveland, not merely large.
    static let notableTypes: [String: String] = [
        "B741": "Boeing 747", "B742": "Boeing 747", "B743": "Boeing 747", "B744": "Boeing 747",
        "B748": "Boeing 747", "B74S": "Boeing 747SP", "BLCF": "Boeing 747 Dreamlifter",
        "A388": "Airbus A380", "A3ST": "Airbus Beluga", "A337": "Airbus BelugaXL",
        "A124": "Antonov An-124", "A225": "Antonov An-225",
        "C5": "Lockheed C-5 Galaxy", "C5M": "Lockheed C-5 Galaxy", "C17": "Boeing C-17 Globemaster III", "B52": "Boeing B-52",
        "V22": "Bell Boeing V-22 Osprey", "DC3": "Douglas DC-3", "CONI": "Lockheed Constellation",
    ]

    public static func of(_ aircraft: Aircraft) -> Rarity? {
        if let squawk = aircraft.squawk, Formatting.emergency(squawk: squawk) != nil { return .emergency(squawk) }
        if let name = aircraft.typeCode.flatMap({ notableTypes[$0] }) { return .notableType(name) }
        if aircraft.isMilitary { return .military }
        if aircraft.category == "A7" { return .helicopter }
        if isNASA(aircraft) { return .specialOperator("NASA") }
        if let year = aircraft.yearBuilt, year < vintageBefore { return .vintage(year: year) }
        return nil
    }

    private static func isNASA(_ aircraft: Aircraft) -> Bool {
        aircraft.callsign?.hasPrefix("NASA") == true
            || aircraft.operatorName?.uppercased().contains("NATIONAL AERONAUTICS") == true
    }
}

/// Which new planes get a silent banner.
public enum NotificationScope: String, Sendable, Codable, CaseIterable {
    case off, rarePlanes, everyPlane

    /// Before rare planes, notifications were a plain on/off switch, which meant every plane.
    public init(legacyEnabled: Bool?) {
        self = legacyEnabled == true ? .everyPlane : .off
    }

    public func includes(rarity: Rarity?) -> Bool {
        switch self {
        case .off: false
        case .rarePlanes: rarity != nil
        case .everyPlane: true
        }
    }
}
