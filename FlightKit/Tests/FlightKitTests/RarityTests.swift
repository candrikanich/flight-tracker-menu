import Foundation
import Testing
@testable import FlightKit

private func aircraft(
    callsign: String? = "UAL1365",
    typeCode: String? = "B737",
    operatorName: String? = "UNITED AIRLINES INC",
    yearBuilt: Int? = 2015,
    squawk: String? = "1234",
    category: String? = "A3",
    isMilitary: Bool = false,
    isMedicalFlight: Bool = false
) -> Aircraft {
    Aircraft(
        hex: "abc123", callsign: callsign, typeCode: typeCode, operatorName: operatorName, yearBuilt: yearBuilt,
        altitudeFeet: 2_100, squawk: squawk, category: category, isMilitary: isMilitary,
        isMedicalFlight: isMedicalFlight,
        coordinate: Coordinate(latitude: 41.45, longitude: -81.80)
    )
}

@Suite struct RarityTests {
    @Test func everydayAirlinerIsNotRare() {
        #expect(Rarity.of(aircraft()) == nil)
    }

    @Test func curatedTypesAreRare() {
        #expect(Rarity.of(aircraft(typeCode: "B748")) == .notableType("Boeing 747"))
        #expect(Rarity.of(aircraft(typeCode: "A388")) == .notableType("Airbus A380"))
        #expect(Rarity.of(aircraft(typeCode: "C17")) == .notableType("Boeing C-17 Globemaster III"))
    }

    @Test func feedMilitaryFlagIsRare() {
        #expect(Rarity.of(aircraft(callsign: "RCH123", typeCode: "C30J", isMilitary: true)) == .military)
    }

    @Test func helicoptersAreRare() {
        #expect(Rarity.of(aircraft(callsign: "N911MH", typeCode: "EC35", category: "A7")) == .helicopter)
    }

    @Test func nasaIsRareByCallsignOrOperator() {
        #expect(Rarity.of(aircraft(callsign: "NASA944", typeCode: "B752")) == .specialOperator("NASA"))
        #expect(Rarity.of(aircraft(
            callsign: "N946NA", operatorName: "NATIONAL AERONAUTICS AND SPACE ADMINISTRATION"
        )) == .specialOperator("NASA"))
    }

    @Test func aircraftBuiltBefore1960AreVintage() {
        #expect(Rarity.of(aircraft(typeCode: "P51", yearBuilt: 1944)) == .vintage(year: 1944))
        #expect(Rarity.of(aircraft(typeCode: "C172", yearBuilt: 1960)) == nil)
    }

    @Test func emergencySquawkIsRare() {
        #expect(Rarity.of(aircraft(squawk: "7700")) == .emergency("7700"))
        #expect(Rarity.of(aircraft(squawk: "7600")) == .emergency("7600"))
    }

    /// A medical helicopter is more interesting as a medical flight than as a helicopter.
    @Test func medicalFlightsAreRareAndOutrankTheAircraft() {
        let medicalHelicopter = aircraft(typeCode: "AS65", category: "A7", isMedicalFlight: true)
        let medicalInEmergency = aircraft(squawk: "7700", isMedicalFlight: true)

        #expect(Rarity.of(medicalHelicopter) == .medicalFlight)
        #expect(Rarity.of(medicalInEmergency) == .emergency("7700"))
        #expect(Formatting.rarity(.medicalFlight) == "Medical flight")
    }

    @Test func mostPressingReasonWins() {
        let militaryC17InEmergency = aircraft(typeCode: "C17", squawk: "7700", isMilitary: true)
        let militaryC17 = aircraft(typeCode: "C17", isMilitary: true)
        let oldMilitaryHelicopter = aircraft(typeCode: "UH1", yearBuilt: 1958, category: "A7", isMilitary: true)

        #expect(Rarity.of(militaryC17InEmergency) == .emergency("7700"))
        #expect(Rarity.of(militaryC17) == .notableType("Boeing C-17 Globemaster III"))
        #expect(Rarity.of(oldMilitaryHelicopter) == .military)
    }

    @Test func labelsReadNaturally() {
        #expect(Formatting.rarity(.notableType("Boeing 747")) == "Boeing 747")
        #expect(Formatting.rarity(.military) == "Military")
        #expect(Formatting.rarity(.helicopter) == "Helicopter")
        #expect(Formatting.rarity(.specialOperator("NASA")) == "NASA")
        #expect(Formatting.rarity(.vintage(year: 1944)) == "Vintage, built 1944")
        #expect(Formatting.rarity(.emergency("7700")) == "Emergency squawk 7700")
    }
}

@Suite struct NotificationScopeTests {
    @Test func eachScopeDecidesWhichPlanesNotify() {
        #expect(!NotificationScope.off.includes(rarity: .military))
        #expect(!NotificationScope.rarePlanes.includes(rarity: nil))
        #expect(NotificationScope.rarePlanes.includes(rarity: .helicopter))
        #expect(NotificationScope.everyPlane.includes(rarity: nil))
        #expect(NotificationScope.everyPlane.includes(rarity: .military))
    }

    @Test func earlierOnOffSettingCarriesOver() {
        #expect(NotificationScope(legacyEnabled: true) == .everyPlane)
        #expect(NotificationScope(legacyEnabled: false) == .off)
        #expect(NotificationScope(legacyEnabled: nil) == .off)
    }
}
