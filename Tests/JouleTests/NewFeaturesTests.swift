import XCTest
@testable import Joule

final class NewFeaturesTests: XCTestCase {

    // MARK: - ReceiptParser Tests

    func testReceiptParserWithThaiReceipt() {
        let receiptText = """
        PEA VOLTA
        Charging Station: Bang Pa-In
        Date: 2026-08-15 14:30
        Duration: 00:45:00
        Energy Delivered: 38.50 kWh
        Rate: 5.79 THB/kWh
        Total Amount: 222.92 THB
        SoC: 22% -> 80%
        Max Speed: 60.5 kW
        """

        let parsed = ReceiptParser.parse(text: receiptText)

        XCTAssertNotNil(parsed.energyAdded)
        XCTAssertEqual(parsed.energyAdded ?? 0, 38.50, accuracy: 0.01)

        XCTAssertNotNil(parsed.totalPrice)
        XCTAssertEqual(parsed.totalPrice ?? 0, 222.92, accuracy: 0.01)

        XCTAssertNotNil(parsed.durationMinutes)
        XCTAssertEqual(parsed.durationMinutes ?? 0, 45.0, accuracy: 0.01)

        XCTAssertNotNil(parsed.startPercentage)
        XCTAssertEqual(parsed.startPercentage ?? 0, 22.0, accuracy: 0.01)

        XCTAssertNotNil(parsed.endPercentage)
        XCTAssertEqual(parsed.endPercentage ?? 0, 80.0, accuracy: 0.01)

        XCTAssertNotNil(parsed.speedKW)
        XCTAssertEqual(parsed.speedKW ?? 0, 60.5, accuracy: 0.01)

        XCTAssertEqual(parsed.locationOrVendor, "PEA VOLTA")
    }

    func testReceiptParserWithUSChargerScreen() {
        let screenText = """
        Electrify America
        Session Summary
        Total: $18.45
        Charged: 42.1 kWh
        Time: 32 min
        Speed: 120.0 kW
        """

        let parsed = ReceiptParser.parse(text: screenText)

        XCTAssertEqual(parsed.energyAdded ?? 0, 42.1, accuracy: 0.01)
        XCTAssertEqual(parsed.totalPrice ?? 0, 18.45, accuracy: 0.01)
        XCTAssertEqual(parsed.durationMinutes ?? 0, 32.0, accuracy: 0.01)
        XCTAssertEqual(parsed.locationOrVendor, "Electrify America")
    }

    // MARK: - PDFReportGenerator Tests

    func testPDFReportGeneratorProducesValidPDF() {
        let vehicle = Vehicle(
            id: "veh-test-pdf",
            name: "Model Y Long Range",
            presetId: "tesla-model-y-lr",
            licensePlate: "1ABC-1234",
            chemistry: .nmc,
            rangeStandard: .wltp,
            nominalCapacityKWh: 75.0,
            nominalRangeKm: 533.0,
            cycleLifeTo80: 1500,
            acEfficiency: 0.90,
            dcEfficiency: 0.95,
            wallChargerKW: 11.0,
            tariffType: .peaTouOffPeak,
            customTariffRate: 2.63,
            gasPreset: .compact,
            gasEfficiencyKmPerL: 14.5,
            gasCustomFuelPrice: 38.5,
            isDefault: true,
            createdAt: Date()
        )

        let sessions = [
            ChargingSession(
                id: "s1",
                vehicleId: vehicle.id,
                locationName: "PEA Bang Phra",
                date: Date().addingTimeInterval(-86400),
                duration: 40,
                energyAdded: 30.0,
                speed: 45.0,
                pricePerUnit: 5.79,
                totalPrice: 173.70,
                chargingType: .dc,
                locationType: .publicStation,
                paymentStatus: .paidUpfront
            ),
            ChargingSession(
                id: "s2",
                vehicleId: vehicle.id,
                locationName: "Home Charger",
                date: Date().addingTimeInterval(-172800),
                duration: 300,
                energyAdded: 45.0,
                speed: 7.4,
                pricePerUnit: 2.63,
                totalPrice: 118.35,
                chargingType: .ac,
                locationType: .home,
                paymentStatus: .deferred
            )
        ]

        let pdfData = PDFReportGenerator.generatePDF(
            sessions: sessions,
            vehicle: vehicle,
            currency: .thb,
            unitSystem: .metric,
            title: "Reimbursement Statement Test",
            dateRangeTitle: "August 2026"
        )

        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertGreaterThan(pdfData.count, 500)

        // Verify PDF Header signature (%PDF-)
        let headerString = String(data: pdfData.prefix(5), encoding: .ascii)
        XCTAssertEqual(headerString, "%PDF-")
    }

    // MARK: - Smart Charging & TOU Savings Tests

    func testSmartChargingSavingsCalculation() {
        let vehicle = Vehicle(
            id: "veh-tou",
            name: "Aion V Plus",
            presetId: "aion-v-plus-80",
            chemistry: .lfp,
            rangeStandard: .nedc,
            nominalCapacityKWh: 80.0,
            nominalRangeKm: 602.0,
            cycleLifeTo80: 3000,
            acEfficiency: 0.90,
            dcEfficiency: 0.95,
            wallChargerKW: 7.4,
            tariffType: .peaTouOffPeak,
            customTariffRate: 2.63,
            gasPreset: .midSizeSUV,
            gasEfficiencyKmPerL: 13.0,
            gasCustomFuelPrice: 38.5,
            isDefault: true,
            createdAt: Date()
        )

        let homeSessions = [
            ChargingSession(
                id: "s-home-1",
                vehicleId: vehicle.id,
                locationName: "Home",
                date: Date(), // Current month
                duration: 360,
                energyAdded: 50.0,
                speed: 7.0,
                pricePerUnit: 2.63,
                totalPrice: 131.50, // 50 * 2.63
                chargingType: .ac,
                locationType: .home,
                paymentStatus: .deferred
            )
        ]

        let stats = ChargingStatistics(
            sessions: homeSessions,
            vehicle: vehicle,
            currency: .thb,
            unitSystem: .metric,
            referenceDate: Date()
        )

        let smartSavings = stats.currentMonthSmartChargingSavings

        XCTAssertTrue(smartSavings.hasSavings)
        XCTAssertEqual(smartSavings.homeEnergyKWh, 50.0, accuracy: 0.1)
        XCTAssertEqual(smartSavings.actualHomeCost, 131.50, accuracy: 0.1)

        // Peak rate is 5.79 -> 50 * 5.79 = 289.50
        XCTAssertEqual(smartSavings.peakEquivalentCost, 289.50, accuracy: 0.1)
        // Savings = 289.50 - 131.50 = 158.00
        XCTAssertEqual(smartSavings.savingsAmount, 158.00, accuracy: 0.1)
        XCTAssertGreaterThan(smartSavings.savingsPercentage, 50.0)
    }
}
