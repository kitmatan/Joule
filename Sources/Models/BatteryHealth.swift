import Foundation

/// Reference constants for the battery pack (default tuned for AION V 602 Luxury - Magazine Battery 2.0 LFP).
enum BatteryConstants {
    /// Nominal gross / usable pack capacity when new in kWh.
    static var defaultNominalCapacityKWh: Double { VehicleProfile.nominalCapacityKWh }
    
    /// Factory rated full range (CLTC) in km.
    static var defaultNominalRangeKm: Double { VehicleProfile.nominalRangeKm }
    
    /// AC charging conversion efficiency (OBC + thermal + battery losses).
    static var defaultACEfficiency: Double { VehicleProfile.acEfficiency }
    
    /// DC fast charging efficiency (dispenser-to-pack DC efficiency).
    static var defaultDCEfficiency: Double { VehicleProfile.dcEfficiency }
    
    /// Theoretical LFP cycle life to 80% SoH under normal operating conditions.
    static let lfpCycleLifeTo80Percent: Double = VehicleProfile.defaultLFPCycleLife
}

/// Confidence rating for a capacity estimation sample based on charging depth (ΔSoC).
enum BatteryHealthConfidence: String, Codable, CaseIterable, Comparable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case unreliable = "Unreliable"
    
    var weight: Double {
        switch self {
        case .high: return 1.0
        case .medium: return 0.5
        case .low: return 0.15
        case .unreliable: return 0.0
        }
    }
    
    var description: String {
        switch self {
        case .high: return "High (ΔSoC ≥ 50%)"
        case .medium: return "Medium (ΔSoC 30–49%)"
        case .low: return "Low (ΔSoC 15–29%)"
        case .unreliable: return "Unreliable (ΔSoC < 15%)"
        }
    }
    
    private var sortOrder: Int {
        switch self {
        case .unreliable: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
    
    static func < (lhs: BatteryHealthConfidence, rhs: BatteryHealthConfidence) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
    
    static func evaluate(socDelta: Double) -> BatteryHealthConfidence {
        if socDelta >= 50.0 {
            return .high
        } else if socDelta >= 30.0 {
            return .medium
        } else if socDelta >= 15.0 {
            return .low
        } else {
            return .unreliable
        }
    }
}

/// A single battery capacity/health estimation computed from a charging session.
struct BatteryHealthDataPoint: Identifiable, Hashable {
    let id: String
    let sessionID: String?
    let date: Date
    let mileage: Double?
    let startSoC: Double
    let endSoC: Double
    let socDelta: Double
    let energyAdded: Double
    let chargingType: ChargingType
    let estimatedCapacityKWh: Double
    let stateOfHealth: Double // percentage e.g. 98.5
    let confidence: BatteryHealthConfidence
    let projectedFullRangeKm: Double?
    
    init(
        id: String = UUID().uuidString,
        sessionID: String? = nil,
        date: Date,
        mileage: Double?,
        startSoC: Double,
        endSoC: Double,
        socDelta: Double,
        energyAdded: Double,
        chargingType: ChargingType,
        estimatedCapacityKWh: Double,
        stateOfHealth: Double,
        confidence: BatteryHealthConfidence,
        projectedFullRangeKm: Double?
    ) {
        self.id = id
        self.sessionID = sessionID
        self.date = date
        self.mileage = mileage
        self.startSoC = startSoC
        self.endSoC = endSoC
        self.socDelta = socDelta
        self.energyAdded = energyAdded
        self.chargingType = chargingType
        self.estimatedCapacityKWh = estimatedCapacityKWh
        self.stateOfHealth = stateOfHealth
        self.confidence = confidence
        self.projectedFullRangeKm = projectedFullRangeKm
    }
}

/// A point along the smoothed longitudinal deterioration trend.
struct BatteryHealthTrendPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let mileage: Double?
    let smoothedSoH: Double
    let smoothedCapacityKWh: Double
    let projectedFullRangeKm: Double?
    
    init(
        date: Date,
        mileage: Double?,
        smoothedSoH: Double,
        smoothedCapacityKWh: Double,
        projectedFullRangeKm: Double?
    ) {
        self.date = date
        self.mileage = mileage
        self.smoothedSoH = smoothedSoH
        self.smoothedCapacityKWh = smoothedCapacityKWh
        self.projectedFullRangeKm = projectedFullRangeKm
    }
}

/// Summary metrics for the vehicle battery deterioration.
struct BatteryHealthSummary {
    let currentSoH: Double
    let currentCapacityKWh: Double
    let nominalCapacityKWh: Double
    let capacityLostKWh: Double
    let totalDegradationPercentage: Double
    
    let degradationPer10kKm: Double?
    let degradationPerYear: Double?
    
    let totalThroughputKWh: Double
    let equivalentFullCycles: Double
    
    let currentProjectedRangeKm: Double?
    let nominalRangeKm: Double
    let rangeLostKm: Double?
    
    let totalSamplesCount: Int
    let reliableSamplesCount: Int
    
    let acEnergyRatio: Double
    let dcEnergyRatio: Double
    
    let assessment: BatteryAssessment
    
    enum BatteryAssessment {
        case excellent
        case good
        case normal
        case degraded
        
        var title: String {
            switch self {
            case .excellent: return "Excellent Health"
            case .good: return "Good Condition"
            case .normal: return "Normal Aging"
            case .degraded: return "Elevated Degradation"
            }
        }
        
        var detail: String {
            switch self {
            case .excellent:
                return "Battery capacity retention is well above average with minimal wear."
            case .good:
                return "Deterioration rate matches standard LFP chemistry longevity expectations."
            case .normal:
                return "Battery capacity is in line with expected calendar and cycle aging."
            case .degraded:
                return "Capacity loss is higher than expected. Consider calibrating at 100% SoC."
            }
        }
        
        var icon: String {
            switch self {
            case .excellent, .good: return "checkmark.shield.fill"
            case .normal: return "battery.100.bolt"
            case .degraded: return "exclamationmark.shield.fill"
            }
        }
    }
}
