import Foundation
import SwiftUI

/// Preset home electricity tariff models (PEA / MEA in Thailand).
enum HomeTariffType: String, CaseIterable, Identifiable, Codable {
    case standardNonTOU = "Standard (Non-TOU)"
    case touPeak = "TOU Peak"
    case touOffPeak = "TOU Off-Peak"
    case custom = "Custom Tariff"
    
    var id: String { rawValue }
    
    var defaultRate: Double {
        switch self {
        case .standardNonTOU: return 4.90
        case .touPeak: return 5.79
        case .touOffPeak: return 2.63
        case .custom: return 4.90
        }
    }
    
    var description: String {
        switch self {
        case .standardNonTOU:
            return "Flat residential rate (฿4.90/kWh incl. Ft & VAT)"
        case .touPeak:
            return "TOU on-peak (Mon–Fri 09:00–22:00, ฿5.79/kWh)"
        case .touOffPeak:
            return "TOU off-peak (Mon–Fri 22:00–09:00 & weekends, ฿2.63/kWh)"
        case .custom:
            return "Custom user-defined electricity rate"
        }
    }
}

/// Vehicle specifications and charging configuration profile.
struct VehicleProfile {
    /// Default values (fallback to AION V 602 Luxury preset).
    static let defaultVehicleName = "AION V 602 Luxury"
    static let defaultNominalCapacityKWh: Double = 75.3
    static let defaultNominalRangeKm: Double = 602.0
    static let defaultACEfficiency: Double = 0.90
    static let defaultDCEfficiency: Double = 0.95
    static let defaultWallChargerKW: Double = 7.0
    static let defaultTariffPerKWh: Double = 4.90
    static let defaultCycleLife: Double = 3000.0
    static let defaultChemistry: BatteryChemistry = .lfp
    static let defaultRangeStandard: RangeStandard = .cltc
    static let taperMinutes: Double = 25.0
    static let fullChargeSoC: Double = 100.0
    
    // User configurable preferences stored in UserDefaults
    @AppStorage("vehicle_preset_id") static var presetId: String = EVPresetCatalog.defaultPresetId
    @AppStorage("vehicle_name") static var vehicleName: String = defaultVehicleName
    @AppStorage("battery_chemistry") static var chemistry: BatteryChemistry = defaultChemistry
    @AppStorage("range_rating_standard") static var rangeStandard: RangeStandard = defaultRangeStandard
    @AppStorage("battery_nominal_capacity_kwh") static var nominalCapacityKWh: Double = defaultNominalCapacityKWh
    @AppStorage("battery_nominal_range_km") static var nominalRangeKm: Double = defaultNominalRangeKm
    @AppStorage("battery_cycle_life_to_80") static var cycleLifeTo80: Double = defaultCycleLife
    @AppStorage("ac_charging_efficiency") static var acEfficiency: Double = defaultACEfficiency
    @AppStorage("dc_charging_efficiency") static var dcEfficiency: Double = defaultDCEfficiency
    @AppStorage("home_wall_charger_kw") static var wallChargerKW: Double = defaultWallChargerKW
    @AppStorage("home_tariff_type") static var tariffType: HomeTariffType = .standardNonTOU
    @AppStorage("home_custom_tariff_rate") static var customTariffRate: Double = defaultTariffPerKWh
    
    /// Effective home charging rate based on current tariff configuration.
    static var effectiveHomeTariff: Double {
        tariffType == .custom ? customTariffRate : tariffType.defaultRate
    }
    
    /// Dynamic chemistry care tip based on active chemistry.
    static var batteryCareTip: String {
        chemistry.careAdvice
    }
    
    /// Apply an official EV Preset to the profile.
    static func applyPreset(_ preset: EVPreset) {
        presetId = preset.id
        vehicleName = preset.displayName
        chemistry = preset.chemistry
        rangeStandard = preset.rangeStandard
        nominalCapacityKWh = preset.nominalCapacityKWh
        nominalRangeKm = preset.nominalRangeKm
        cycleLifeTo80 = preset.expectedCycleLife
        wallChargerKW = preset.defaultWallChargerKW
    }
    
    /// Calculates energy drawn at the wall meter from a given SoC delta.
    static func wallEnergyKWh(socDelta: Double) -> Double {
        guard socDelta > 0 else { return 0 }
        return (socDelta / 100.0) * nominalCapacityKWh / acEfficiency
    }
    
    /// Calculates estimated AC charging duration in minutes.
    static func durationMinutes(wallEnergyKWh kWh: Double, endsFull: Bool) -> Double {
        guard wallChargerKW > 0 else { return 0 }
        return (kWh / wallChargerKW * 60.0) + (endsFull ? taperMinutes : 0)
    }
    
    /// Calculates estimated home charging cost from energy drawn at the meter.
    static func homeCost(wallEnergyKWh kWh: Double, rateOverride: Double? = nil) -> Double {
        let rate = rateOverride ?? effectiveHomeTariff
        return kWh * rate
    }
    
    /// Reset vehicle parameters back to the active preset or factory defaults.
    static func resetToDefaults() {
        if let preset = EVPresetCatalog.preset(forId: presetId) {
            applyPreset(preset)
        } else {
            presetId = EVPresetCatalog.defaultPresetId
            vehicleName = defaultVehicleName
            chemistry = defaultChemistry
            rangeStandard = defaultRangeStandard
            nominalCapacityKWh = defaultNominalCapacityKWh
            nominalRangeKm = defaultNominalRangeKm
            cycleLifeTo80 = defaultCycleLife
            wallChargerKW = defaultWallChargerKW
        }
        acEfficiency = defaultACEfficiency
        dcEfficiency = defaultDCEfficiency
        tariffType = .standardNonTOU
        customTariffRate = defaultTariffPerKWh
    }
}
