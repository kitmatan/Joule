import Foundation
import SwiftUI

/// Supported measurement unit systems in Joule.
enum UnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric = "Metric"
    case imperial = "Imperial"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .metric: return "Metric (km, km/kWh)"
        case .imperial: return "Imperial (mi, mi/kWh)"
        }
    }
    
    /// Short distance unit abbreviation.
    var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }
    
    /// Long distance unit name.
    var distanceUnitLong: String {
        switch self {
        case .metric: return "Kilometers"
        case .imperial: return "Miles"
        }
    }
    
    /// Driving efficiency unit string.
    var efficiencyUnit: String {
        switch self {
        case .metric: return "km/kWh"
        case .imperial: return "mi/kWh"
        }
    }

    /// Driving consumption unit string.
    var consumptionUnit: String {
        switch self {
        case .metric: return "kWh/100km"
        case .imperial: return "kWh/100mi"
        }
    }
    
    /// Rate per distance unit suffix e.g. "/km" or "/mi".
    var perDistanceUnit: String {
        switch self {
        case .metric: return "/km"
        case .imperial: return "/mi"
        }
    }
    
    /// Degradation rate denominator e.g. "10k km" or "10k mi".
    var degradationDistanceUnit: String {
        switch self {
        case .metric: return "10k km"
        case .imperial: return "10k mi"
        }
    }
    
    /// Long degradation rate description.
    var degradationDistanceDescription: String {
        switch self {
        case .metric: return "10,000 km"
        case .imperial: return "10,000 miles"
        }
    }
    
    // MARK: - Conversions (Base stored unit is Kilometers)
    
    /// Converts a distance from Kilometers to the active unit system.
    func convertFromKm(_ km: Double) -> Double {
        switch self {
        case .metric: return km
        case .imperial: return km * 0.621371192
        }
    }
    
    /// Converts a distance from the active unit system to Kilometers.
    func convertToKm(_ value: Double) -> Double {
        switch self {
        case .metric: return value
        case .imperial: return value / 0.621371192
        }
    }
    
    /// Formats a distance value (provided in Kilometers base) with the active unit.
    func formatDistance(km: Double, decimals: Int = 0) -> String {
        let value = convertFromKm(km)
        return String(format: "%.\(decimals)f %@", value, distanceUnit)
    }
    
    /// Formats driving efficiency (provided in km/kWh base) to the active unit (km/kWh or mi/kWh).
    func formatEfficiency(kmPerKWh: Double, decimals: Int = 1) -> String {
        let value = convertFromKm(kmPerKWh)
        return String(format: "%.\(decimals)f %@", value, efficiencyUnit)
    }

    /// Formats driving consumption (provided in km/kWh base) to the active unit (kWh/100km or kWh/100mi).
    func formatConsumption(kmPerKWh: Double, decimals: Int = 1) -> String {
        let eff = convertFromKm(kmPerKWh)
        guard eff > 0 else { return "N/A" }
        let value = 100.0 / eff
        return String(format: "%.\(decimals)f %@", value, consumptionUnit)
    }

    /// Formats driving consumption directly from energy (kWh) and distance (km).
    func formatConsumption(energy: Double, distanceKm: Double, decimals: Int = 1) -> String {
        let dist = convertFromKm(distanceKm)
        guard dist > 0, energy > 0 else { return "N/A" }
        let value = (energy / dist) * 100.0
        return String(format: "%.\(decimals)f %@", value, consumptionUnit)
    }

    /// Computes consumption value in the active unit (kWh/100km or kWh/100mi) from km/kWh base.
    func consumptionValue(kmPerKWh: Double) -> Double {
        let eff = convertFromKm(kmPerKWh)
        guard eff > 0 else { return 0 }
        return 100.0 / eff
    }

    /// Computes consumption value in the active unit (kWh/100km or kWh/100mi) from energy (kWh) and distance (km).
    func consumptionValue(energy: Double, distanceKm: Double) -> Double {
        let dist = convertFromKm(distanceKm)
        guard dist > 0 else { return 0 }
        return (energy / dist) * 100.0
    }
}

/// Unit modes for driving efficiency charts.
enum EfficiencyChartUnit: String, CaseIterable, Identifiable, Codable {
    case consumption = "kWh/100km"
    case distancePerEnergy = "km/kWh"

    var id: String { rawValue }

    func label(for unitSystem: UnitSystem) -> String {
        switch self {
        case .consumption:
            return unitSystem.consumptionUnit
        case .distancePerEnergy:
            return unitSystem.efficiencyUnit
        }
    }
}
