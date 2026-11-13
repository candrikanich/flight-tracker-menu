import Foundation
import Testing
@testable import FlightKit

/// Who a private plane is registered to. Airline flights already lead with the airline.
@Suite struct OwnerLineTests {
    func line(_ owner: String?, callsign: String? = "N29B", routeAirline: String? = nil) -> String? {
        let aircraft = Aircraft(hex: "abc123", callsign: callsign, operatorName: owner, altitudeFeet: 20_000,
                                coordinate: Coordinate(latitude: 41.45, longitude: -81.80))
        return Formatting.ownerLine(aircraft, routeAirline: routeAirline)
    }

    @Test func aPrivatePlaneSaysWhoItIsRegisteredTo() {
        #expect(line("BATTELLE MEMORIAL INSTITUTE") == "Registered to Battelle Memorial Institute")
    }

    /// The FAA registry is all capitals; the card isn't.
    @Test func namesReadInMixedCaseAndKeepTheirAcronyms() {
        #expect(line("FSI INC") == "Registered to FSI Inc")
        #expect(line("FE ENCORE PLUS III LLC") == "Registered to FE Encore Plus III LLC")
        #expect(line("GLC PC-12 LLC") == "Registered to GLC PC-12 LLC")
        #expect(line("MICHIANA AIR ACTIVITIES INC") == "Registered to Michiana Air Activities Inc")
        #expect(line("NATIONAL AERONAUTICS AND SPACE ADMINISTRATION")
            == "Registered to National Aeronautics and Space Administration")
    }

    /// A bank holding title for someone else isn't who flies the plane, so naming it would mislead.
    @Test func trusteesAreLeftOut() {
        #expect(line("BANK OF UTAH TRUSTEE") == nil)
        #expect(line("WILMINGTON TRUST CO TRUSTEE") == nil)
    }

    /// Private owners are listed as "LAST FIRST MIDDLE". A person's name doesn't belong on the card.
    @Test func peopleAreLeftOut() {
        #expect(line("BATTS GREGORY W") == nil)
        #expect(line("STURT MICHAEL H, STURT DARLINE K") == nil)
        #expect(line("CANCELLED/NOT ASSIGNED") == nil)
    }

    @Test func organizationsBeyondCompaniesStillShow() {
        #expect(line("LAUREL HIGHLANDS AERONAUTICAL ACADEMY")
            == "Registered to Laurel Highlands Aeronautical Academy")
        #expect(line("PARK VIEW HEALTH SYSTEM INC") == "Registered to Park View Health System Inc")
    }

    @Test func aNameAlreadyInMixedCaseIsKept() {
        #expect(line("NetJets Sales Inc") == "Registered to NetJets Sales Inc")
    }

    @Test func airlineFlightsAreLeftOut() {
        #expect(line("UNITED AIRLINES INC", callsign: "UAL1365") == nil)
        #expect(line("REPUBLIC AIRWAYS INC", callsign: nil, routeAirline: "United Airlines") == nil)
    }

    @Test func noOwnerMeansNoLine() {
        #expect(line(nil) == nil)
    }
}
