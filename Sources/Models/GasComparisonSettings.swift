import Foundation
import SwiftUI

/// Preset categories for internal combustion engine (ICE) baseline vehicles.
enum GasBaselinePreset: String, CaseIterable, Identifiable, Codable {
    case midSizeSUV = "Mid-Size SUV / Crossover"
    case compact = "Compact Sedan / Eco Car"
    case fullSizeSUV = "Full-Size SUV / Truck"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    /// Default fuel efficiency in km/L (Metric).
    var defaultEfficiencyKmPerL: Double {
        switch self {
        case .midSizeSUV: return 13.0
        case .compact: return 16.0
        case .fullSizeSUV: return 9.0
        case .custom: return 13.0
        }
    }
    
    /// Default fuel efficiency in Miles Per Gallon (US MPG).
    var defaultEfficiencyMPG: Double {
        GasComparisonSettings.convertKmPerLToMPG(defaultEfficiencyKmPerL)
    }
    
    /// Display title with localized efficiency hint.
    func title(for unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            switch self {
            case .midSizeSUV: return "Mid-Size SUV / Crossover (13.0 km/L)"
            case .compact: return "Compact Sedan / Eco Car (16.0 km/L)"
            case .fullSizeSUV: return "Full-Size SUV / Truck (9.0 km/L)"
            case .custom: return "Custom Baseline"
            }
        case .imperial:
            switch self {
            case .midSizeSUV: return "Mid-Size SUV / Crossover (30.6 MPG)"
            case .compact: return "Compact Sedan / Eco Car (37.6 MPG)"
            case .fullSizeSUV: return "Full-Size SUV / Truck (21.2 MPG)"
            case .custom: return "Custom Baseline"
            }
        }
    }
    
    /// Short subtitle / description of vehicle type.
    var subtitle: String {
        switch self {
        case .midSizeSUV:
            return "Standard equivalent for most EV crossovers & sedans (e.g. Corolla Cross, CR-V, RAV4)."
        case .compact:
            return "Small compact hatchbacks and city eco cars (e.g. Yaris, City, Civic)."
        case .fullSizeSUV:
            return "Larger body-on-frame SUVs, pickup trucks, and high-displacement vehicles."
        case .custom:
            return "User-defined fuel efficiency and fuel price."
        }
    }
}

/// Result summary of gas cost savings calculation.
struct GasSavingsSummary: Equatable {
    /// Total equivalent cost if driven with a gas engine vehicle in active currency.
    let gasCost: Double
    /// Actual total EV charging cost in active currency.
    let evCost: Double
    /// Net money saved (gasCost - evCost). Can be negative if EV charging was unusually high.
    var netSavings: Double { gasCost - evCost }
    /// Percentage savings compared to gas ((gasCost - evCost) / gasCost * 100).
    var savingsPercentage: Double {
        guard gasCost > 0 else { return 0 }
        return ((gasCost - evCost) / gasCost) * 100.0
    }
    /// Fuel volume avoided (in Liters for Metric, US Gallons for Imperial).
    let fuelAvoided: Double
    /// Unit string for fuel volume ("L" or "gal").
    let fuelUnit: String
    /// Gas vehicle running cost per distance unit (e.g. ฿/km or $/mi).
    let gasCostPerDistance: Double
    /// EV running cost per distance unit (e.g. ฿/km or $/mi).
    let evCostPerDistance: Double
    /// Difference in cost per distance unit (gas - ev).
    var costDifferencePerDistance: Double {
        gasCostPerDistance - evCostPerDistance
    }
}

/// Global settings and calculations for Gas Engine Baseline comparisons.
struct GasComparisonSettings {
    // MARK: - Constants & Defaults
    static let defaultPreset: GasBaselinePreset = .midSizeSUV
    static let defaultEfficiencyKmPerL: Double = 13.0
    static let defaultFuelPriceTHB: Double = 38.00
    
    /// Conversion constants
    static let kmPerLToMPGConversionFactor: Double = 2.35214583
    static let litersToGallonsConversionFactor: Double = 0.264172052
    
    // MARK: - AppStorage Keys
    @AppStorage("gas_baseline_preset") static var preset: GasBaselinePreset = defaultPreset
    @AppStorage("gas_fuel_efficiency_km_per_l") static var efficiencyKmPerL: Double = defaultEfficiencyKmPerL
    @AppStorage("gas_custom_fuel_price") static var customFuelPrice: Double = defaultFuelPriceTHB
    
    // MARK: - Unit Conversions
    
    /// Converts km/L to US MPG.
    static func convertKmPerLToMPG(_ kmPerL: Double) -> Double {
        kmPerL * kmPerLToMPGConversionFactor
    }
    
    /// Converts US MPG to km/L.
    static func convertMPGToKmPerL(_ mpg: Double) -> Double {
        guard mpg > 0 else { return 0 }
        return mpg / kmPerLToMPGConversionFactor
    }
    
    /// Converts Liters to US Gallons.
    static func convertLitersToGallons(_ liters: Double) -> Double {
        liters * litersToGallonsConversionFactor
    }
    
    /// Converts US Gallons to Liters.
    static func convertGallonsToLiters(_ gallons: Double) -> Double {
        guard gallons > 0 else { return 0 }
        return gallons / litersToGallonsConversionFactor
    }
    
    /// Active fuel efficiency in user's unit system (km/L or MPG).
    static func activeEfficiency(unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric: return efficiencyKmPerL
        case .imperial: return convertKmPerLToMPG(efficiencyKmPerL)
        }
    }
    
    /// Fuel efficiency unit string ("km/L" or "MPG").
    static func efficiencyUnit(unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric: return "km/L"
        case .imperial: return "MPG"
        }
    }
    
    /// Fuel volume unit string ("L" or "gal").
    static func fuelVolumeUnit(unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric: return "L"
        case .imperial: return "gal"
        }
    }
    
    /// Default fuel price per unit volume (L or gal) based on active currency and unit system.
    static func defaultFuelPrice(for currency: AppCurrency, unitSystem: UnitSystem) -> Double {
        switch (currency, unitSystem) {
        case (.thb, .metric): return 38.00
        case (.thb, .imperial): return 143.85 // ฿38/L * 3.7854
        case (.usd, .imperial): return 3.60  // $3.60/gal
        case (.usd, .metric): return 0.95   // ~$0.95/L
        case (.eur, .metric): return 1.75   // €1.75/L
        case (.eur, .imperial): return 6.62
        case (.gbp, .metric): return 1.45   // £1.45/L
        case (.gbp, .imperial): return 5.49
        case (.aud, .metric): return 1.90   // A$1.90/L
        case (.aud, .imperial): return 7.19
        case (.cad, .metric): return 1.60   // C$1.60/L
        case (.cad, .imperial): return 6.06
        case (.jpy, .metric): return 175.0  // ¥175/L
        case (.jpy, .imperial): return 662.0
        case (.cny, .metric): return 7.80   // ¥7.80/L
        case (.cny, .imperial): return 29.53
        case (.krw, .metric): return 1650.0 // ₩1,650/L
        case (.krw, .imperial): return 6246.0
        case (.sgd, .metric): return 2.80
        case (.sgd, .imperial): return 10.60
        case (.chf, .metric): return 1.80
        case (.chf, .imperial): return 6.81
        case (.sek, .metric): return 18.00
        case (.sek, .imperial): return 68.14
        case (.nok, .metric): return 21.00
        case (.nok, .imperial): return 79.49
        case (.inr, .metric): return 100.00
        case (.inr, .imperial): return 378.54
        }
    }
    
    /// Effective fuel price in the active unit volume (per Liter in metric, per Gallon in imperial).
    static func effectiveFuelPrice(currency: AppCurrency, unitSystem: UnitSystem) -> Double {
        if customFuelPrice > 0 {
            return customFuelPrice
        }
        return defaultFuelPrice(for: currency, unitSystem: unitSystem)
    }
    
    /// Applies a preset and resets efficiency to preset default.
    static func applyPreset(_ newPreset: GasBaselinePreset) {
        preset = newPreset
        if newPreset != .custom {
            efficiencyKmPerL = newPreset.defaultEfficiencyKmPerL
        }
    }
    
    // MARK: - Savings Calculations
    
    /// Calculates equivalent gas cost and savings for a specific distance in Kilometers.
    static func calculateSavings(
        distanceKm: Double,
        evCost: Double,
        currency: AppCurrency = VehicleProfile.currency,
        unitSystem: UnitSystem = VehicleProfile.unitSystem
    ) -> GasSavingsSummary {
        guard distanceKm > 0, efficiencyKmPerL > 0 else {
            return GasSavingsSummary(
                gasCost: 0,
                evCost: evCost,
                fuelAvoided: 0,
                fuelUnit: fuelVolumeUnit(unitSystem: unitSystem),
                gasCostPerDistance: 0,
                evCostPerDistance: 0
            )
        }
        
        let fuelPrice = effectiveFuelPrice(currency: currency, unitSystem: unitSystem)
        let convertedDistance = unitSystem.convertFromKm(distanceKm)
        
        let litersNeeded = distanceKm / efficiencyKmPerL
        let fuelAvoided: Double
        let gasCost: Double
        
        switch unitSystem {
        case .metric:
            fuelAvoided = litersNeeded
            gasCost = litersNeeded * fuelPrice
        case .imperial:
            let gallonsNeeded = convertLitersToGallons(litersNeeded)
            fuelAvoided = gallonsNeeded
            gasCost = gallonsNeeded * fuelPrice
        }
        
        let gasCostPerDist = convertedDistance > 0 ? gasCost / convertedDistance : 0
        let evCostPerDist = convertedDistance > 0 ? evCost / convertedDistance : 0
        
        return GasSavingsSummary(
            gasCost: gasCost,
            evCost: evCost,
            fuelAvoided: fuelAvoided,
            fuelUnit: fuelVolumeUnit(unitSystem: unitSystem),
            gasCostPerDistance: gasCostPerDist,
            evCostPerDistance: evCostPerDist
        )
    }
    
    /// Calculates savings estimated from EV energy added (kWh) when exact odometer distance is unavailable.
    static func calculateSavings(
        energyKWh: Double,
        evCost: Double,
        ratedEfficiencyKmPerKWh: Double,
        currency: AppCurrency = VehicleProfile.currency,
        unitSystem: UnitSystem = VehicleProfile.unitSystem
    ) -> GasSavingsSummary {
        guard energyKWh > 0, ratedEfficiencyKmPerKWh > 0 else {
            return GasSavingsSummary(
                gasCost: 0,
                evCost: evCost,
                fuelAvoided: 0,
                fuelUnit: fuelVolumeUnit(unitSystem: unitSystem),
                gasCostPerDistance: 0,
                evCostPerDistance: 0
            )
        }
        
        let estimatedDistanceKm = energyKWh * ratedEfficiencyKmPerKWh
        return calculateSavings(
            distanceKm: estimatedDistanceKm,
            evCost: evCost,
            currency: currency,
            unitSystem: unitSystem
        )
    }
    
    /// Resets gas comparison settings back to defaults.
    static func resetToDefaults() {
        preset = defaultPreset
        efficiencyKmPerL = defaultEfficiencyKmPerL
        customFuelPrice = defaultFuelPriceTHB
    }
}
