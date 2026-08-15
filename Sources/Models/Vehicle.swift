import Foundation
import SwiftUI

/// A first-class EV profile representing a single vehicle in the user's garage.
struct Vehicle: Identifiable, Codable, Hashable, Equatable {
    var id: String
    var name: String
    var presetId: String
    var licensePlate: String?
    var chemistry: BatteryChemistry
    var rangeStandard: RangeStandard
    var nominalCapacityKWh: Double
    var nominalRangeKm: Double
    var cycleLifeTo80: Double
    var acEfficiency: Double
    var dcEfficiency: Double
    var wallChargerKW: Double
    var tariffType: HomeTariffType
    var customTariffRate: Double
    var gasPreset: GasBaselinePreset
    var gasEfficiencyKmPerL: Double
    var gasCustomFuelPrice: Double
    var isDefault: Bool
    var createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        name: String = VehicleProfile.defaultVehicleName,
        presetId: String = EVPresetCatalog.defaultPresetId,
        licensePlate: String? = nil,
        chemistry: BatteryChemistry = VehicleProfile.defaultChemistry,
        rangeStandard: RangeStandard = VehicleProfile.defaultRangeStandard,
        nominalCapacityKWh: Double = VehicleProfile.defaultNominalCapacityKWh,
        nominalRangeKm: Double = VehicleProfile.defaultNominalRangeKm,
        cycleLifeTo80: Double = VehicleProfile.defaultCycleLife,
        acEfficiency: Double = VehicleProfile.defaultACEfficiency,
        dcEfficiency: Double = VehicleProfile.defaultDCEfficiency,
        wallChargerKW: Double = VehicleProfile.defaultWallChargerKW,
        tariffType: HomeTariffType = .peaStandardNonTOU,
        customTariffRate: Double = VehicleProfile.defaultTariffPerKWh,
        gasPreset: GasBaselinePreset = GasComparisonSettings.defaultPreset,
        gasEfficiencyKmPerL: Double = GasComparisonSettings.defaultEfficiencyKmPerL,
        gasCustomFuelPrice: Double = GasComparisonSettings.defaultFuelPriceTHB,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.presetId = presetId
        self.licensePlate = licensePlate
        self.chemistry = chemistry
        self.rangeStandard = rangeStandard
        self.nominalCapacityKWh = nominalCapacityKWh
        self.nominalRangeKm = nominalRangeKm
        self.cycleLifeTo80 = cycleLifeTo80
        self.acEfficiency = acEfficiency
        self.dcEfficiency = dcEfficiency
        self.wallChargerKW = wallChargerKW
        self.tariffType = tariffType
        self.customTariffRate = customTariffRate
        self.gasPreset = gasPreset
        self.gasEfficiencyKmPerL = gasEfficiencyKmPerL
        self.gasCustomFuelPrice = gasCustomFuelPrice
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
    
    /// Create a vehicle instance initialized from a catalog preset.
    static func fromPreset(_ preset: EVPreset, isDefault: Bool = false) -> Vehicle {
        Vehicle(
            id: UUID().uuidString,
            name: preset.displayName,
            presetId: preset.id,
            licensePlate: nil,
            chemistry: preset.chemistry,
            rangeStandard: preset.rangeStandard,
            nominalCapacityKWh: preset.nominalCapacityKWh,
            nominalRangeKm: preset.nominalRangeKm,
            cycleLifeTo80: preset.expectedCycleLife,
            acEfficiency: VehicleProfile.defaultACEfficiency,
            dcEfficiency: VehicleProfile.defaultDCEfficiency,
            wallChargerKW: preset.defaultWallChargerKW,
            tariffType: .peaStandardNonTOU,
            customTariffRate: VehicleProfile.defaultTariffPerKWh,
            gasPreset: GasComparisonSettings.defaultPreset,
            gasEfficiencyKmPerL: GasComparisonSettings.defaultEfficiencyKmPerL,
            gasCustomFuelPrice: GasComparisonSettings.defaultFuelPriceTHB,
            isDefault: isDefault,
            createdAt: Date()
        )
    }
    
    /// Creates the initial default vehicle migrated from legacy UserDefaults / @AppStorage settings.
    static func createDefaultFromLegacy() -> Vehicle {
        let defaults = UserDefaults.standard
        let savedName = defaults.string(forKey: "vehicle_name") ?? VehicleProfile.defaultVehicleName
        let savedPresetId = defaults.string(forKey: "vehicle_preset_id") ?? EVPresetCatalog.defaultPresetId
        
        let chemistryRaw = defaults.string(forKey: "battery_chemistry") ?? ""
        let chemistry = BatteryChemistry(rawValue: chemistryRaw) ?? VehicleProfile.defaultChemistry
        
        let rangeStandardRaw = defaults.string(forKey: "range_rating_standard") ?? ""
        let rangeStandard = RangeStandard(rawValue: rangeStandardRaw) ?? VehicleProfile.defaultRangeStandard
        
        let capacity = defaults.object(forKey: "battery_nominal_capacity_kwh") != nil
            ? defaults.double(forKey: "battery_nominal_capacity_kwh")
            : VehicleProfile.defaultNominalCapacityKWh
        
        let range = defaults.object(forKey: "battery_nominal_range_km") != nil
            ? defaults.double(forKey: "battery_nominal_range_km")
            : VehicleProfile.defaultNominalRangeKm
        
        let cycleLife = defaults.object(forKey: "battery_cycle_life_to_80") != nil
            ? defaults.double(forKey: "battery_cycle_life_to_80")
            : VehicleProfile.defaultCycleLife
        
        let acEff = defaults.object(forKey: "ac_charging_efficiency") != nil
            ? defaults.double(forKey: "ac_charging_efficiency")
            : VehicleProfile.defaultACEfficiency
        
        let dcEff = defaults.object(forKey: "dc_charging_efficiency") != nil
            ? defaults.double(forKey: "dc_charging_efficiency")
            : VehicleProfile.defaultDCEfficiency
        
        let wallKW = defaults.object(forKey: "home_wall_charger_kw") != nil
            ? defaults.double(forKey: "home_wall_charger_kw")
            : VehicleProfile.defaultWallChargerKW
        
        let tariffRaw = defaults.string(forKey: "home_tariff_type") ?? ""
        let tariffType = HomeTariffType(rawValue: tariffRaw) ?? .peaStandardNonTOU
        
        let customTariff = defaults.object(forKey: "home_custom_tariff_rate") != nil
            ? defaults.double(forKey: "home_custom_tariff_rate")
            : VehicleProfile.defaultTariffPerKWh
        
        let gasPresetRaw = defaults.string(forKey: "gas_baseline_preset") ?? ""
        let gasPreset = GasBaselinePreset(rawValue: gasPresetRaw) ?? GasComparisonSettings.defaultPreset
        
        let gasEff = defaults.object(forKey: "gas_fuel_efficiency_km_per_l") != nil
            ? defaults.double(forKey: "gas_fuel_efficiency_km_per_l")
            : GasComparisonSettings.defaultEfficiencyKmPerL
        
        let gasPrice = defaults.object(forKey: "gas_custom_fuel_price") != nil
            ? defaults.double(forKey: "gas_custom_fuel_price")
            : GasComparisonSettings.defaultFuelPriceTHB
        
        return Vehicle(
            id: UUID().uuidString,
            name: savedName,
            presetId: savedPresetId,
            licensePlate: nil,
            chemistry: chemistry,
            rangeStandard: rangeStandard,
            nominalCapacityKWh: capacity,
            nominalRangeKm: range,
            cycleLifeTo80: cycleLife,
            acEfficiency: acEff,
            dcEfficiency: dcEff,
            wallChargerKW: wallKW,
            tariffType: tariffType,
            customTariffRate: customTariff,
            gasPreset: gasPreset,
            gasEfficiencyKmPerL: gasEff,
            gasCustomFuelPrice: gasPrice,
            isDefault: true,
            createdAt: Date()
        )
    }
    
    /// Effective home charging rate based on tariff configuration.
    var effectiveHomeTariff: Double {
        tariffType == .custom ? customTariffRate : tariffType.defaultRate
    }
    
    /// Dynamic chemistry care tip based on active chemistry.
    var batteryCareTip: String {
        chemistry.careAdvice
    }
    
    /// Rated driving efficiency in km/kWh based on rated range and nominal pack capacity.
    var ratedEfficiencyKmPerKWh: Double {
        nominalCapacityKWh > 0 ? nominalRangeKm / nominalCapacityKWh : 6.0
    }
    
    /// Calculates energy drawn at the wall meter from a given SoC delta.
    func wallEnergyKWh(socDelta: Double) -> Double {
        guard socDelta > 0 else { return 0 }
        return (socDelta / 100.0) * nominalCapacityKWh / acEfficiency
    }
    
    /// Calculates estimated AC charging duration in minutes.
    func durationMinutes(wallEnergyKWh kWh: Double, endsFull: Bool) -> Double {
        guard wallChargerKW > 0 else { return 0 }
        return (kWh / wallChargerKW * 60.0) + (endsFull ? VehicleProfile.taperMinutes : 0)
    }
    
    /// Calculates estimated home charging cost from energy drawn at the meter.
    func homeCost(wallEnergyKWh kWh: Double, rateOverride: Double? = nil) -> Double {
        let rate = rateOverride ?? effectiveHomeTariff
        return kWh * rate
    }
    
    /// Applies an official EV Preset to this vehicle.
    mutating func applyPreset(_ preset: EVPreset) {
        self.presetId = preset.id
        self.name = preset.displayName
        self.chemistry = preset.chemistry
        self.rangeStandard = preset.rangeStandard
        self.nominalCapacityKWh = preset.nominalCapacityKWh
        self.nominalRangeKm = preset.nominalRangeKm
        self.cycleLifeTo80 = preset.expectedCycleLife
        self.wallChargerKW = preset.defaultWallChargerKW
    }
}
