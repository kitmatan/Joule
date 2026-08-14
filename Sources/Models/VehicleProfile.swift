import Foundation
import SwiftUI

/// Region grouping for electricity tariff models.
enum TariffRegion: String, CaseIterable, Identifiable {
    case thailand = "Thailand (PEA / MEA)"
    case unitedStates = "United States"
    case europeUK = "Europe & UK"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var tariffs: [HomeTariffType] {
        switch self {
        case .thailand:
            return [.peaStandardNonTOU, .peaTouPeak, .peaTouOffPeak]
        case .unitedStates:
            return [.usStandardFlat, .usTouPeak, .usTouOffPeak, .usCaliforniaTiered]
        case .europeUK:
            return [.euStandardFlat, .euOffPeak, .ukStandardFlat, .ukAgileOffPeak]
        case .custom:
            return [.custom]
        }
    }
}

/// Preset home electricity tariff models across Thailand, US, and Europe/UK.
enum HomeTariffType: String, CaseIterable, Identifiable, Codable {
    // Thailand (PEA / MEA)
    case peaStandardNonTOU = "Standard (Non-TOU)"
    case peaTouPeak = "TOU Peak"
    case peaTouOffPeak = "TOU Off-Peak"
    
    // United States
    case usStandardFlat = "US Standard Flat ($0.16)"
    case usTouPeak = "US TOU Peak ($0.32)"
    case usTouOffPeak = "US EV Off-Peak ($0.09)"
    case usCaliforniaTiered = "US High Demand / Tiered ($0.45)"
    
    // Europe & UK
    case euStandardFlat = "EU Standard Flat (€0.28)"
    case euOffPeak = "EU Night Off-Peak (€0.15)"
    case ukStandardFlat = "UK Standard Flat (£0.25)"
    case ukAgileOffPeak = "UK EV Overnight (£0.09)"
    
    // Custom
    case custom = "Custom Tariff"
    
    var id: String { rawValue }
    
    var region: TariffRegion {
        switch self {
        case .peaStandardNonTOU, .peaTouPeak, .peaTouOffPeak:
            return .thailand
        case .usStandardFlat, .usTouPeak, .usTouOffPeak, .usCaliforniaTiered:
            return .unitedStates
        case .euStandardFlat, .euOffPeak, .ukStandardFlat, .ukAgileOffPeak:
            return .europeUK
        case .custom:
            return .custom
        }
    }
    
    var associatedCurrency: AppCurrency {
        switch self {
        case .peaStandardNonTOU, .peaTouPeak, .peaTouOffPeak:
            return .thb
        case .usStandardFlat, .usTouPeak, .usTouOffPeak, .usCaliforniaTiered:
            return .usd
        case .euStandardFlat, .euOffPeak:
            return .eur
        case .ukStandardFlat, .ukAgileOffPeak:
            return .gbp
        case .custom:
            return VehicleProfile.currency
        }
    }
    
    var defaultRate: Double {
        switch self {
        case .peaStandardNonTOU: return 4.90
        case .peaTouPeak: return 5.79
        case .peaTouOffPeak: return 2.63
        case .usStandardFlat: return 0.16
        case .usTouPeak: return 0.32
        case .usTouOffPeak: return 0.09
        case .usCaliforniaTiered: return 0.45
        case .euStandardFlat: return 0.28
        case .euOffPeak: return 0.15
        case .ukStandardFlat: return 0.25
        case .ukAgileOffPeak: return 0.09
        case .custom: return 4.90
        }
    }
    
    var description: String {
        switch self {
        case .peaStandardNonTOU:
            return "Flat residential rate (฿4.90/kWh incl. Ft & VAT)"
        case .peaTouPeak:
            return "TOU on-peak (Mon–Fri 09:00–22:00, ฿5.79/kWh)"
        case .peaTouOffPeak:
            return "TOU off-peak (Mon–Fri 22:00–09:00 & weekends, ฿2.63/kWh)"
        case .usStandardFlat:
            return "US national average residential electricity rate ($0.16/kWh)"
        case .usTouPeak:
            return "US high-demand summer on-peak tariff ($0.32/kWh)"
        case .usTouOffPeak:
            return "US super off-peak EV overnight charging rate ($0.09/kWh)"
        case .usCaliforniaTiered:
            return "US California / high-cost region baseline tiered rate ($0.45/kWh)"
        case .euStandardFlat:
            return "European Union average household electricity tariff (€0.28/kWh)"
        case .euOffPeak:
            return "EU dual-tariff nighttime off-peak EV charging rate (€0.15/kWh)"
        case .ukStandardFlat:
            return "United Kingdom standard domestic variable tariff (£0.25/kWh)"
        case .ukAgileOffPeak:
            return "UK overnight EV smart tariff (e.g. Octopus Go @ £0.09/kWh)"
        case .custom:
            return "Custom user-defined electricity rate in active currency"
        }
    }
    
    // Support legacy raw values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Standard (Non-TOU)", "peaStandardNonTOU": self = .peaStandardNonTOU
        case "TOU Peak", "peaTouPeak": self = .peaTouPeak
        case "TOU Off-Peak", "peaTouOffPeak": self = .peaTouOffPeak
        case "Custom Tariff", "custom": self = .custom
        default:
            self = HomeTariffType(rawValue: raw) ?? .peaStandardNonTOU
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
    static let defaultUnitSystem: UnitSystem = .metric
    static let defaultCurrency: AppCurrency = .thb
    static let taperMinutes: Double = 25.0
    static let fullChargeSoC: Double = 100.0
    
    // User configurable preferences stored in UserDefaults
    @AppStorage("app_unit_system") static var unitSystem: UnitSystem = defaultUnitSystem
    @AppStorage("app_currency") static var currency: AppCurrency = defaultCurrency
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
    @AppStorage("home_tariff_type") static var tariffType: HomeTariffType = .peaStandardNonTOU
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
        tariffType = .peaStandardNonTOU
        customTariffRate = defaultTariffPerKWh
    }
}
