import XCTest
@testable import Joule

final class TariffAndEnergyTests: XCTestCase {

    func testRegionalTariffRatesAndCurrencies() {
        // Thailand (PEA / MEA)
        XCTAssertEqual(HomeTariffType.peaStandardNonTOU.defaultRate, 4.90)
        XCTAssertEqual(HomeTariffType.peaStandardNonTOU.associatedCurrency, .thb)
        XCTAssertEqual(HomeTariffType.peaStandardNonTOU.region, .thailand)

        XCTAssertEqual(HomeTariffType.peaTouPeak.defaultRate, 5.79)
        XCTAssertEqual(HomeTariffType.peaTouPeak.associatedCurrency, .thb)

        XCTAssertEqual(HomeTariffType.peaTouOffPeak.defaultRate, 2.63)
        XCTAssertEqual(HomeTariffType.peaTouOffPeak.associatedCurrency, .thb)

        // United States
        XCTAssertEqual(HomeTariffType.usStandardFlat.defaultRate, 0.16)
        XCTAssertEqual(HomeTariffType.usStandardFlat.associatedCurrency, .usd)
        XCTAssertEqual(HomeTariffType.usStandardFlat.region, .unitedStates)

        XCTAssertEqual(HomeTariffType.usTouPeak.defaultRate, 0.32)
        XCTAssertEqual(HomeTariffType.usTouPeak.associatedCurrency, .usd)

        XCTAssertEqual(HomeTariffType.usTouOffPeak.defaultRate, 0.09)
        XCTAssertEqual(HomeTariffType.usTouOffPeak.associatedCurrency, .usd)

        XCTAssertEqual(HomeTariffType.usCaliforniaTiered.defaultRate, 0.45)
        XCTAssertEqual(HomeTariffType.usCaliforniaTiered.associatedCurrency, .usd)

        // Europe & UK
        XCTAssertEqual(HomeTariffType.euStandardFlat.defaultRate, 0.28)
        XCTAssertEqual(HomeTariffType.euStandardFlat.associatedCurrency, .eur)
        XCTAssertEqual(HomeTariffType.euStandardFlat.region, .europeUK)

        XCTAssertEqual(HomeTariffType.euOffPeak.defaultRate, 0.15)
        XCTAssertEqual(HomeTariffType.euOffPeak.associatedCurrency, .eur)

        XCTAssertEqual(HomeTariffType.ukStandardFlat.defaultRate, 0.25)
        XCTAssertEqual(HomeTariffType.ukStandardFlat.associatedCurrency, .gbp)
        XCTAssertEqual(HomeTariffType.ukStandardFlat.region, .europeUK)

        XCTAssertEqual(HomeTariffType.ukAgileOffPeak.defaultRate, 0.09)
        XCTAssertEqual(HomeTariffType.ukAgileOffPeak.associatedCurrency, .gbp)
    }

    func testDeltaSoCEnergyEstimationFormula() {
        // Vehicle profile nominal: 75.3 kWh, AC efficiency: 0.90
        VehicleProfile.nominalCapacityKWh = 75.3
        VehicleProfile.acEfficiency = 0.90

        // 50% SoC delta (e.g. 30% -> 80%)
        // Battery energy added = 0.50 * 75.3 = 37.65 kWh
        // Wall meter energy = 37.65 / 0.90 = 41.8333... kWh
        let energy50 = VehicleProfile.wallEnergyKWh(socDelta: 50.0)
        XCTAssertEqual(energy50, 41.8333, accuracy: 0.001)

        // 100% SoC delta (0% -> 100%)
        // Wall meter energy = 75.3 / 0.90 = 83.6666... kWh
        let energy100 = VehicleProfile.wallEnergyKWh(socDelta: 100.0)
        XCTAssertEqual(energy100, 83.6667, accuracy: 0.001)

        // 0% or negative SoC delta returns 0
        XCTAssertEqual(VehicleProfile.wallEnergyKWh(socDelta: 0.0), 0.0)
        XCTAssertEqual(VehicleProfile.wallEnergyKWh(socDelta: -10.0), 0.0)
    }

    func testChargingDurationCalculations() {
        VehicleProfile.wallChargerKW = 7.0

        // 42.0 kWh with 7.0 kW charger:
        // Basic duration = (42.0 / 7.0) * 60 = 360 min (6 hours)
        let durationPartial = VehicleProfile.durationMinutes(wallEnergyKWh: 42.0, endsFull: false)
        XCTAssertEqual(durationPartial, 360.0)

        // If charging to 100% (endsFull = true), adds taperMinutes (25 min):
        // Total duration = 360 + 25 = 385 min
        let durationFull = VehicleProfile.durationMinutes(wallEnergyKWh: 42.0, endsFull: true)
        XCTAssertEqual(durationFull, 385.0)

        // 0 wall energy
        XCTAssertEqual(VehicleProfile.durationMinutes(wallEnergyKWh: 0.0, endsFull: false), 0.0)
    }

    func testHomeCostCalculationsAndTOUDifference() {
        // Charging 40 kWh at meter
        let energyKWh = 40.0

        // PEA TOU Peak (฿5.79/kWh)
        let peakCost = VehicleProfile.homeCost(wallEnergyKWh: energyKWh, rateOverride: HomeTariffType.peaTouPeak.defaultRate)
        XCTAssertEqual(peakCost, 231.60, accuracy: 0.01)

        // PEA TOU Off-Peak (฿2.63/kWh)
        let offPeakCost = VehicleProfile.homeCost(wallEnergyKWh: energyKWh, rateOverride: HomeTariffType.peaTouOffPeak.defaultRate)
        XCTAssertEqual(offPeakCost, 105.20, accuracy: 0.01)

        // Savings by charging off-peak: 231.60 - 105.20 = 126.40 THB (> 54% savings)
        let savings = peakCost - offPeakCost
        XCTAssertEqual(savings, 126.40, accuracy: 0.01)
        XCTAssertGreaterThan(savings / peakCost, 0.50)

        // US TOU Peak ($0.32) vs US EV Off-Peak ($0.09)
        let usPeakCost = VehicleProfile.homeCost(wallEnergyKWh: energyKWh, rateOverride: HomeTariffType.usTouPeak.defaultRate)
        let usOffPeakCost = VehicleProfile.homeCost(wallEnergyKWh: energyKWh, rateOverride: HomeTariffType.usTouOffPeak.defaultRate)
        XCTAssertEqual(usPeakCost, 12.80, accuracy: 0.01)
        XCTAssertEqual(usOffPeakCost, 3.60, accuracy: 0.01)

        // Custom rate fallback
        VehicleProfile.customTariffRate = 3.50
        VehicleProfile.tariffType = .custom
        let customCost = VehicleProfile.homeCost(wallEnergyKWh: energyKWh)
        XCTAssertEqual(customCost, 140.00, accuracy: 0.01)
    }
}
