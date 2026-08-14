import XCTest
@testable import Joule

final class VehicleProfileTests: XCTestCase {

    func testEVPresetCatalogRetrievalAndBrandList() {
        let brands = EVPresetCatalog.brands
        XCTAssertTrue(brands.contains("GAC AION"))
        XCTAssertTrue(brands.contains("BYD"))
        XCTAssertTrue(brands.contains("Tesla"))
        XCTAssertTrue(brands.contains("MG"))
        XCTAssertTrue(brands.contains("Hyundai"))
        XCTAssertTrue(brands.contains("Kia"))
        XCTAssertTrue(brands.contains("Deepal"))
        XCTAssertTrue(brands.contains("Volvo"))
        XCTAssertTrue(brands.contains("BMW"))
        XCTAssertTrue(brands.contains("ORA"))

        // Brand filtering
        let teslaPresets = EVPresetCatalog.presets(forBrand: "Tesla")
        XCTAssertFalse(teslaPresets.isEmpty)
        XCTAssertTrue(teslaPresets.allSatisfy { $0.brand == "Tesla" })

        let bydPresets = EVPresetCatalog.presets(forBrand: "BYD")
        XCTAssertFalse(bydPresets.isEmpty)
        XCTAssertTrue(bydPresets.allSatisfy { $0.brand == "BYD" })

        // Specific preset lookups
        let aionV = EVPresetCatalog.preset(forId: "gac_aion_v_602")
        XCTAssertNotNil(aionV)
        XCTAssertEqual(aionV?.brand, "GAC AION")
        XCTAssertEqual(aionV?.model, "AION V")
        XCTAssertEqual(aionV?.nominalCapacityKWh, 75.3)
        XCTAssertEqual(aionV?.nominalRangeKm, 602.0)
        XCTAssertEqual(aionV?.chemistry, .lfp)
        XCTAssertEqual(aionV?.rangeStandard, .cltc)

        let teslaM3 = EVPresetCatalog.preset(forId: "tesla_m3_rwd")
        XCTAssertNotNil(teslaM3)
        XCTAssertEqual(teslaM3?.brand, "Tesla")
        XCTAssertEqual(teslaM3?.model, "Model 3")
        XCTAssertEqual(teslaM3?.chemistry, .lfp)
        XCTAssertEqual(teslaM3?.nominalCapacityKWh, 60.0)

        // Non-existent preset returns nil
        XCTAssertNil(EVPresetCatalog.preset(forId: "non_existent_preset_id"))

        // Default preset
        XCTAssertEqual(EVPresetCatalog.defaultPreset.id, EVPresetCatalog.defaultPresetId)
    }

    func testVehicleProfilePresetApplicationAndReset() {
        guard let atto3 = EVPresetCatalog.preset(forId: "byd_atto_3_ext") else {
            XCTFail("Missing BYD Atto 3 Extended preset in catalog")
            return
        }

        // Apply preset
        VehicleProfile.applyPreset(atto3)

        XCTAssertEqual(VehicleProfile.presetId, "byd_atto_3_ext")
        XCTAssertEqual(VehicleProfile.vehicleName, atto3.displayName)
        XCTAssertEqual(VehicleProfile.chemistry, .lfp)
        XCTAssertEqual(VehicleProfile.nominalCapacityKWh, 60.48)
        XCTAssertEqual(VehicleProfile.nominalRangeKm, 480.0)
        XCTAssertEqual(VehicleProfile.cycleLifeTo80, 3000.0)
        XCTAssertEqual(VehicleProfile.wallChargerKW, 7.0)

        // Reset to defaults
        VehicleProfile.resetToDefaults()
        XCTAssertEqual(VehicleProfile.acEfficiency, VehicleProfile.defaultACEfficiency)
        XCTAssertEqual(VehicleProfile.dcEfficiency, VehicleProfile.defaultDCEfficiency)
        XCTAssertEqual(VehicleProfile.tariffType, .peaStandardNonTOU)
    }

    func testCustomChemistryValidationAndCareTips() {
        // LFP
        VehicleProfile.chemistry = .lfp
        XCTAssertTrue(VehicleProfile.batteryCareTip.contains("Lithium Iron Phosphate"))

        // NMC
        VehicleProfile.chemistry = .nmc
        XCTAssertTrue(VehicleProfile.batteryCareTip.contains("Nickel Manganese Cobalt"))

        // NCA
        VehicleProfile.chemistry = .nca
        XCTAssertTrue(VehicleProfile.batteryCareTip.contains("Nickel Cobalt Aluminum"))

        // Other
        VehicleProfile.chemistry = .other
        XCTAssertTrue(VehicleProfile.batteryCareTip.contains("manufacturer"))
    }

    func testRangeCycleConversions() {
        // WLTP normalized factor = 1.00
        // NEDC normalized factor = 1.14
        // CLTC normalized factor = 1.22
        // EPA normalized factor = 0.89

        let wltpRange = 500.0

        // WLTP to NEDC: 500 * (1.14 / 1.00) = 570.0
        let nedc = RangeStandard.wltp.convert(range: wltpRange, to: .nedc)
        XCTAssertEqual(nedc, 570.0, accuracy: 0.1)

        // WLTP to CLTC: 500 * (1.22 / 1.00) = 610.0
        let cltc = RangeStandard.wltp.convert(range: wltpRange, to: .cltc)
        XCTAssertEqual(cltc, 610.0, accuracy: 0.1)

        // WLTP to EPA: 500 * (0.89 / 1.00) = 445.0
        let epa = RangeStandard.wltp.convert(range: wltpRange, to: .epa)
        XCTAssertEqual(epa, 445.0, accuracy: 0.1)

        // CLTC to WLTP: 610 / 1.22 = 500.0
        let convertedWLTP = RangeStandard.cltc.convert(range: 610.0, to: .wltp)
        XCTAssertEqual(convertedWLTP, 500.0, accuracy: 0.1)

        // CLTC to EPA: (610 / 1.22) * 0.89 = 445.0
        let cltcToEPA = RangeStandard.cltc.convert(range: 610.0, to: .epa)
        XCTAssertEqual(cltcToEPA, 445.0, accuracy: 0.1)

        // Identity conversion
        XCTAssertEqual(RangeStandard.wltp.convert(range: 500.0, to: .wltp), 500.0)
        XCTAssertEqual(RangeStandard.cltc.convert(range: 602.0, to: .cltc), 602.0)

        // Custom standard does not alter range
        XCTAssertEqual(RangeStandard.custom.convert(range: 450.0, to: .wltp), 450.0)
        XCTAssertEqual(RangeStandard.wltp.convert(range: 450.0, to: .custom), 450.0)
    }
}
