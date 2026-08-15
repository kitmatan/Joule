import XCTest
@testable import Joule

final class GasSavingsTests: XCTestCase {

    func testGasBaselinePresets() {
        XCTAssertEqual(GasBaselinePreset.midSizeSUV.defaultEfficiencyKmPerL, 13.0)
        XCTAssertEqual(GasBaselinePreset.compact.defaultEfficiencyKmPerL, 16.0)
        XCTAssertEqual(GasBaselinePreset.fullSizeSUV.defaultEfficiencyKmPerL, 9.0)
        XCTAssertEqual(GasBaselinePreset.custom.defaultEfficiencyKmPerL, 13.0)
        
        // Titles and unit adaptations
        let midMetric = GasBaselinePreset.midSizeSUV.title(for: .metric)
        let midImperial = GasBaselinePreset.midSizeSUV.title(for: .imperial)
        XCTAssertTrue(midMetric.contains("13.0 km/L"))
        XCTAssertTrue(midImperial.contains("30.6 MPG"))
    }
    
    func testUnitConversions() {
        // 13.0 km/L to MPG: 13.0 * 2.35214583 ≈ 30.578 MPG
        let mpg = GasComparisonSettings.convertKmPerLToMPG(13.0)
        XCTAssertEqual(mpg, 30.57789, accuracy: 0.01)
        
        // 30.57789 MPG back to km/L
        let kmPerL = GasComparisonSettings.convertMPGToKmPerL(mpg)
        XCTAssertEqual(kmPerL, 13.0, accuracy: 0.01)
        
        // Liters to Gallons: 100 L * 0.264172 ≈ 26.417 gal
        let gal = GasComparisonSettings.convertLitersToGallons(100.0)
        XCTAssertEqual(gal, 26.4172, accuracy: 0.01)
        
        // Gallons to Liters: 26.4172 gal back to L
        let liters = GasComparisonSettings.convertGallonsToLiters(gal)
        XCTAssertEqual(liters, 100.0, accuracy: 0.01)
    }
    
    func testDefaultFuelPricesPerCurrency() {
        XCTAssertEqual(GasComparisonSettings.defaultFuelPrice(for: .thb, unitSystem: .metric), 38.00)
        XCTAssertEqual(GasComparisonSettings.defaultFuelPrice(for: .usd, unitSystem: .imperial), 3.60)
        XCTAssertEqual(GasComparisonSettings.defaultFuelPrice(for: .eur, unitSystem: .metric), 1.75)
        XCTAssertEqual(GasComparisonSettings.defaultFuelPrice(for: .gbp, unitSystem: .metric), 1.45)
        XCTAssertEqual(GasComparisonSettings.defaultFuelPrice(for: .aud, unitSystem: .metric), 1.90)
        XCTAssertEqual(GasComparisonSettings.defaultFuelPrice(for: .jpy, unitSystem: .metric), 175.0)
    }
    
    func testDistanceBasedSavingsCalculationMetric() {
        // Given a 1,300 km trip:
        // Gas vehicle at 13.0 km/L uses 100 L.
        // At ฿38.00 / L, Gas Cost = ฿3,800.
        // EV charging cost = ฿1,000.
        // Net Savings = ฿2,800 (73.68%).
        // Gas Cost per km = ฿38 / 13 = ฿2.923/km.
        // EV Cost per km = ฿1,000 / 1,300 = ฿0.769/km.
        
        GasComparisonSettings.efficiencyKmPerL = 13.0
        GasComparisonSettings.customFuelPrice = 38.00
        
        let summary = GasComparisonSettings.calculateSavings(
            distanceKm: 1300.0,
            evCost: 1000.0,
            currency: .thb,
            unitSystem: .metric
        )
        
        XCTAssertEqual(summary.gasCost, 3800.0, accuracy: 0.01)
        XCTAssertEqual(summary.evCost, 1000.0, accuracy: 0.01)
        XCTAssertEqual(summary.netSavings, 2800.0, accuracy: 0.01)
        XCTAssertEqual(summary.savingsPercentage, 73.684, accuracy: 0.01)
        XCTAssertEqual(summary.fuelAvoided, 100.0, accuracy: 0.01)
        XCTAssertEqual(summary.fuelUnit, "L")
        XCTAssertEqual(summary.gasCostPerDistance, 3800.0 / 1300.0, accuracy: 0.01)
        XCTAssertEqual(summary.evCostPerDistance, 1000.0 / 1300.0, accuracy: 0.01)
        XCTAssertEqual(summary.costDifferencePerDistance, (3800.0 - 1000.0) / 1300.0, accuracy: 0.01)
    }
    
    func testDistanceBasedSavingsCalculationImperial() {
        // Distance in km: 1000 km (≈ 621.371 miles)
        // Gas vehicle: 13.0 km/L
        // Liters needed = 1000 / 13 = 76.923 L
        // Gallons needed = 76.923 * 0.264172 = 20.3209 gal
        // Fuel price: $3.60 / gal
        // Gas Cost = 20.3209 * 3.60 = $73.155
        // EV Cost = $20.00
        // Net Savings = $53.155
        
        GasComparisonSettings.efficiencyKmPerL = 13.0
        GasComparisonSettings.customFuelPrice = 3.60
        
        let summary = GasComparisonSettings.calculateSavings(
            distanceKm: 1000.0,
            evCost: 20.00,
            currency: .usd,
            unitSystem: .imperial
        )
        
        XCTAssertEqual(summary.gasCost, 73.155, accuracy: 0.1)
        XCTAssertEqual(summary.evCost, 20.00, accuracy: 0.01)
        XCTAssertEqual(summary.netSavings, 53.155, accuracy: 0.1)
        XCTAssertEqual(summary.fuelUnit, "gal")
        XCTAssertEqual(summary.fuelAvoided, 20.32, accuracy: 0.1)
    }
    
    func testEnergyBasedSavingsCalculationFallback() {
        // 50 kWh added with rated efficiency of 6.0 km/kWh
        // Estimated distance = 300 km
        // Gas needed = 300 / 13.0 = 23.0769 L
        // Gas cost at ฿38/L = ฿876.92
        // EV Cost = ฿245.00
        // Net Savings = ฿631.92
        
        GasComparisonSettings.efficiencyKmPerL = 13.0
        GasComparisonSettings.customFuelPrice = 38.00
        
        let summary = GasComparisonSettings.calculateSavings(
            energyKWh: 50.0,
            evCost: 245.00,
            ratedEfficiencyKmPerKWh: 6.0,
            currency: .thb,
            unitSystem: .metric
        )
        
        XCTAssertEqual(summary.gasCost, 876.92, accuracy: 0.1)
        XCTAssertEqual(summary.evCost, 245.00, accuracy: 0.01)
        XCTAssertEqual(summary.netSavings, 631.92, accuracy: 0.1)
        XCTAssertEqual(summary.savingsPercentage, (631.92 / 876.92) * 100.0, accuracy: 0.1)
    }
    
    func testEdgeCasesAndZeroDivision() {
        let zeroDistance = GasComparisonSettings.calculateSavings(
            distanceKm: 0,
            evCost: 0,
            currency: .thb,
            unitSystem: .metric
        )
        XCTAssertEqual(zeroDistance.gasCost, 0)
        XCTAssertEqual(zeroDistance.netSavings, 0)
        XCTAssertEqual(zeroDistance.savingsPercentage, 0)
        
        let zeroEnergy = GasComparisonSettings.calculateSavings(
            energyKWh: 0,
            evCost: 100,
            ratedEfficiencyKmPerKWh: 0,
            currency: .thb,
            unitSystem: .metric
        )
        XCTAssertEqual(zeroEnergy.gasCost, 0)
        XCTAssertEqual(zeroEnergy.netSavings, -100)
    }
    
    func testApplyPresetAndReset() {
        GasComparisonSettings.applyPreset(.compact)
        XCTAssertEqual(GasComparisonSettings.preset, .compact)
        XCTAssertEqual(GasComparisonSettings.efficiencyKmPerL, 16.0)
        
        GasComparisonSettings.applyPreset(.fullSizeSUV)
        XCTAssertEqual(GasComparisonSettings.preset, .fullSizeSUV)
        XCTAssertEqual(GasComparisonSettings.efficiencyKmPerL, 9.0)
        
        GasComparisonSettings.resetToDefaults()
        XCTAssertEqual(GasComparisonSettings.preset, .midSizeSUV)
        XCTAssertEqual(GasComparisonSettings.efficiencyKmPerL, 13.0)
        XCTAssertEqual(GasComparisonSettings.customFuelPrice, 38.00)
    }
}
