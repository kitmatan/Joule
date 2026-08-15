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
        XCTAssertEqual(metric.consumptionUnit, "kWh/100km")
        XCTAssertEqual(imperial.consumptionUnit, "kWh/100mi")

        // Distance formatting
        XCTAssertEqual(metric.formatDistance(km: 150.0), "150 km")
        XCTAssertEqual(imperial.formatDistance(km: 160.9344), "100 mi")

        // Driving Efficiency (Distance per Energy)
        XCTAssertEqual(metric.formatEfficiency(kmPerKWh: 6.25), "6.2 km/kWh")
        XCTAssertEqual(imperial.formatEfficiency(kmPerKWh: 6.25), "3.9 mi/kWh")

        // Driving Consumption (Energy per Distance in kWh/100km and kWh/100mi)
        // 6.25 km/kWh -> 100 / 6.25 = 16.0 kWh/100km
        XCTAssertEqual(metric.formatConsumption(kmPerKWh: 6.25), "16.0 kWh/100km")
        XCTAssertEqual(metric.consumptionValue(kmPerKWh: 6.25), 16.0, accuracy: 0.01)
        XCTAssertEqual(metric.formatConsumption(energy: 40.0, distanceKm: 250.0), "16.0 kWh/100km")

        // Imperial: 6.25 km/kWh = 3.88357 mi/kWh -> 100 / 3.88357 = 25.749 kWh/100mi
        XCTAssertEqual(imperial.formatConsumption(kmPerKWh: 6.25), "25.7 kWh/100mi")
        XCTAssertEqual(imperial.consumptionValue(kmPerKWh: 6.25), 25.749, accuracy: 0.01)

        // Edge cases
        XCTAssertEqual(metric.formatConsumption(kmPerKWh: 0), "N/A")
        XCTAssertEqual(metric.formatConsumption(energy: 0, distanceKm: 100), "N/A")
        XCTAssertEqual(metric.formatConsumption(energy: 50, distanceKm: 0), "N/A")
    }

    func testEfficiencyChartUnits() {
        let metric = UnitSystem.metric
        let imperial = UnitSystem.imperial

        XCTAssertEqual(EfficiencyChartUnit.consumption.label(for: metric), "kWh/100km")
        XCTAssertEqual(EfficiencyChartUnit.distancePerEnergy.label(for: metric), "km/kWh")

        XCTAssertEqual(EfficiencyChartUnit.consumption.label(for: imperial), "kWh/100mi")
        XCTAssertEqual(EfficiencyChartUnit.distancePerEnergy.label(for: imperial), "mi/kWh")

        // Driving efficiency point conversion
        let point = DrivingEfficiencyPoint(
            date: Date(),
            distanceKm: 200.0,
            energyKWh: 32.0,
            kmPerKWh: 200.0 / 32.0, // 6.25 km/kWh
            kwhPer100km: (32.0 / 200.0) * 100.0 // 16.0 kWh/100km
        )

        XCTAssertEqual(point.value(for: .consumption, unitSystem: metric), 16.0, accuracy: 0.01)
        XCTAssertEqual(point.value(for: .distancePerEnergy, unitSystem: metric), 6.25, accuracy: 0.01)
        XCTAssertEqual(point.value(for: .distancePerEnergy, unitSystem: imperial), 6.25 * 0.621371192, accuracy: 0.01)
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

    func testDashboardHeroMetrics() {
        let vehicle = Vehicle(
            name: "Aion V Plus",
            chemistry: .lfp,
            nominalCapacityKWh: 72.0,
            nominalRangeKm: 505.0,
            isDefault: true
        )
        
        let session1 = ChargingSession(
            date: Date(),
            duration: 1800,
            energyAdded: 35.0,
            chargingFee: 175.0,
            totalPrice: 175.0,
            endPercentage: 80
        )
        
        XCTAssertEqual(vehicle.name, "Aion V Plus")
        XCTAssertEqual(vehicle.chemistry.rawValue, "LFP")
        XCTAssertEqual(session1.endPercentage, 80)
        XCTAssertEqual(session1.energyAdded, 35.0)
        
        let savings = GasComparisonSettings.calculateSavings(
            energyKWh: 35.0,
            evCost: 175.0,
            ratedEfficiencyKmPerKWh: 6.5,
            currency: .thb,
            unitSystem: .metric
        )
        XCTAssertGreaterThan(savings.gasCost, 0)
        XCTAssertGreaterThan(savings.netSavings, 0)
    }
}
