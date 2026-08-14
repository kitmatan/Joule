import XCTest
@testable import Joule

final class JouleTests: XCTestCase {

    func testUnitConversions() {
        let metric = UnitSystem.metric
        let imperial = UnitSystem.imperial

        // 100 km to miles
        let miles = imperial.convertFromKm(100.0)
        XCTAssertEqual(miles, 62.1371192, accuracy: 0.001)

        // 100 miles to km
        let km = imperial.convertToKm(100.0)
        XCTAssertEqual(km, 160.9344, accuracy: 0.001)

        // Metric identity
        XCTAssertEqual(metric.convertFromKm(100.0), 100.0)
        XCTAssertEqual(metric.convertToKm(100.0), 100.0)

        // Unit labels
        XCTAssertEqual(metric.distanceUnit, "km")
        XCTAssertEqual(imperial.distanceUnit, "mi")
        XCTAssertEqual(metric.efficiencyUnit, "km/kWh")
        XCTAssertEqual(imperial.efficiencyUnit, "mi/kWh")

        // Distance formatting
        XCTAssertEqual(metric.formatDistance(km: 150.0), "150 km")
        XCTAssertEqual(imperial.formatDistance(km: 160.9344), "100 mi")
    }

    func testAppCurrencyFormatting() {
        let thb = AppCurrency.thb
        let usd = AppCurrency.usd
        let eur = AppCurrency.eur
        let gbp = AppCurrency.gbp
        let jpy = AppCurrency.jpy

        XCTAssertEqual(thb.symbol, "฿")
        XCTAssertEqual(usd.symbol, "$")
        XCTAssertEqual(eur.symbol, "€")
        XCTAssertEqual(gbp.symbol, "£")
        XCTAssertEqual(jpy.symbol, "¥")

        XCTAssertEqual(thb.format(500), "฿500.00")
        XCTAssertEqual(usd.format(25.50), "$25.50")
        XCTAssertEqual(jpy.format(1200), "¥1,200")

        XCTAssertEqual(usd.formatRate(0.35), "$0.35/kWh")
        XCTAssertEqual(eur.formatCostPerDistance(cost: 0.08, distanceUnit: "km"), "€0.08/km")
        XCTAssertEqual(usd.formatCostPerDistance(cost: 0.12, distanceUnit: "mi"), "$0.12/mi")
    }

    func testRegionalTariffs() {
        // Regions
        let regions = TariffRegion.allCases
        XCTAssertTrue(regions.contains(.thailand))
        XCTAssertTrue(regions.contains(.unitedStates))
        XCTAssertTrue(regions.contains(.europeUK))
        XCTAssertTrue(regions.contains(.custom))

        // Tariff lookup
        XCTAssertEqual(HomeTariffType.usStandardFlat.defaultRate, 0.16)
        XCTAssertEqual(HomeTariffType.usTouOffPeak.defaultRate, 0.09)
        XCTAssertEqual(HomeTariffType.euStandardFlat.defaultRate, 0.28)
        XCTAssertEqual(HomeTariffType.ukAgileOffPeak.defaultRate, 0.09)
        XCTAssertEqual(HomeTariffType.peaTouOffPeak.defaultRate, 2.63)

        // Region categorization
        XCTAssertTrue(TariffRegion.unitedStates.tariffs.contains(.usStandardFlat))
        XCTAssertTrue(TariffRegion.europeUK.tariffs.contains(.euStandardFlat))
        XCTAssertTrue(TariffRegion.thailand.tariffs.contains(.peaTouOffPeak))
    }

    func testBatteryHealthDegradationWithUnits() {
        let summary = BatteryHealthSummary(
            currentSoH: 92.3,
            currentCapacityKWh: 60.0,
            nominalCapacityKWh: 65.0,
            capacityLostKWh: 5.0,
            totalDegradationPercentage: 7.7,
            degradationPer10kKm: 0.5,
            degradationPerYear: 2.1,
            totalThroughputKWh: 9750,
            equivalentFullCycles: 150,
            currentProjectedRangeKm: 460.0,
            nominalRangeKm: 500.0,
            rangeLostKm: 40.0,
            totalSamplesCount: 25,
            reliableSamplesCount: 15,
            acEnergyRatio: 0.7,
            dcEnergyRatio: 0.3,
            assessment: .good
        )

        // Degradation rate for Metric (per 10k km)
        XCTAssertEqual(summary.degradationPer10kDistance(unit: UnitSystem.metric), 0.5)
        XCTAssertEqual(summary.formattedDegradationRate(unit: UnitSystem.metric), "-0.50% / 10k km")

        // Degradation rate for Imperial (per 10k mi = 0.5 * 1.609344 = 0.804672)
        let miRate = summary.degradationPer10kDistance(unit: UnitSystem.imperial)
        XCTAssertNotNil(miRate)
        XCTAssertEqual(miRate!, 0.804672, accuracy: 0.001)
        XCTAssertEqual(summary.formattedDegradationRate(unit: UnitSystem.imperial), "-0.80% / 10k mi")
    }

    func testCSVParserCurrencyStripping() {
        let csvContent = """
Date,Location,Vendor,Energy (kWh),Duration (min),Speed (kW),Charging Fee,Booking Fee,Overtime Fee,Total Cost,Start %,End %,Mileage
2026-08-01 10:00,Supercharger,Tesla,45.5,35,78,$15.50,$0.00,$0.00,$15.50,15,80,12500
2026-08-02 12:00,Ionity Berlin,Ionity,30.0,20,90,€18.00,€0.00,€0.00,€18.00,20,70,12650
2026-08-03 14:00,Home,Home,25.0,240,7,฿65.00,฿0.00,฿0.00,฿65.00,40,80,12780
"""
        let result = CSVParser.parseSessions(from: csvContent)
        let sessions = result.sessions
        XCTAssertEqual(sessions.count, 3)

        XCTAssertEqual(sessions[0].chargingFee, 15.50)
        XCTAssertEqual(sessions[0].totalPrice, 15.50)

        XCTAssertEqual(sessions[1].chargingFee, 18.00)
        XCTAssertEqual(sessions[1].totalPrice, 18.00)

        XCTAssertEqual(sessions[2].chargingFee, 65.00)
        XCTAssertEqual(sessions[2].totalPrice, 65.00)
    }
}
