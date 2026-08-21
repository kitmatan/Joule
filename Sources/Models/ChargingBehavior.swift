import Foundation
import SwiftUI

/// Letter grade representation of charging habit friendliness towards battery longevity.
enum ChargingBehaviorGrade: String, Codable, CaseIterable, Comparable {
    case aPlus = "A+"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var title: String {
        switch self {
        case .aPlus: return "Optimal Habits (A+)"
        case .a: return "Great Habits (A)"
        case .b: return "Good Habits (B)"
        case .c: return "Moderate Stress (C)"
        case .d: return "High Wear Habits (D)"
        }
    }

    var color: Color {
        switch self {
        case .aPlus, .a: return .green
        case .b: return .blue
        case .c: return .orange
        case .d: return .red
        }
    }

    private var sortOrder: Int {
        switch self {
        case .d: return 0
        case .c: return 1
        case .b: return 2
        case .a: return 3
        case .aPlus: return 4
        }
    }

    static func < (lhs: ChargingBehaviorGrade, rhs: ChargingBehaviorGrade) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    static func grade(for score: Double) -> ChargingBehaviorGrade {
        switch score {
        case 93.0...: return .aPlus
        case 85.0..<93.0: return .a
        case 70.0..<85.0: return .b
        case 50.0..<70.0: return .c
        default: return .d
        }
    }
}

/// Overall qualitative longevity assessment based on charging behavior.
enum ChargingLongevityAssessment: String, Codable {
    case optimal = "Optimal for Longevity"
    case good = "Good Condition Routine"
    case moderateWear = "Moderate Thermal / Cycle Stress"
    case highWear = "Elevated Battery Degradation Risk"

    var icon: String {
        switch self {
        case .optimal, .good: return "checkmark.seal.fill"
        case .moderateWear: return "exclamationmark.triangle.fill"
        case .highWear: return "exclamationmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .optimal: return .green
        case .good: return .blue
        case .moderateWear: return .orange
        case .highWear: return .red
        }
    }
}

/// Category of battery care recommendation.
enum ChargingRecommendationCategory: String, Codable, CaseIterable {
    case chargingSpeed = "Charging Speed"
    case targetSoC = "Target SoC"
    case deepDischarge = "Discharge Buffer"
    case bmsCalibration = "BMS Calibration"
    case generalCare = "General Care"

    var icon: String {
        switch self {
        case .chargingSpeed: return "bolt.fill"
        case .targetSoC: return "battery.100.bolt"
        case .deepDischarge: return "battery.25"
        case .bmsCalibration: return "arrow.triangle.2.circlepath.circle.fill"
        case .generalCare: return "heart.fill"
        }
    }
}

/// Priority / tone level for a charging behavior recommendation.
enum ChargingRecommendationLevel: String, Codable, Comparable {
    case positive = "Well Done"
    case tip = "Optimization Tip"
    case caution = "Attention Needed"

    var sortOrder: Int {
        switch self {
        case .positive: return 0
        case .tip: return 1
        case .caution: return 2
        }
    }

    static func < (lhs: ChargingRecommendationLevel, rhs: ChargingRecommendationLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    var icon: String {
        switch self {
        case .positive: return "checkmark.circle.fill"
        case .tip: return "lightbulb.fill"
        case .caution: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .green
        case .tip: return .blue
        case .caution: return .orange
        }
    }
}

/// An actionable recommendation tailored to the driver's vehicle chemistry and observed habits.
struct ChargingRecommendation: Identifiable, Hashable, Codable {
    var id: String
    var category: ChargingRecommendationCategory
    var level: ChargingRecommendationLevel
    var title: String
    var summary: String
    var impactDescription: String
    var actionableAdvice: String
    var observedMetricFormatted: String

    init(
        id: String = UUID().uuidString,
        category: ChargingRecommendationCategory,
        level: ChargingRecommendationLevel,
        title: String,
        summary: String,
        impactDescription: String,
        actionableAdvice: String,
        observedMetricFormatted: String
    ) {
        self.id = id
        self.category = category
        self.level = level
        self.title = title
        self.summary = summary
        self.impactDescription = impactDescription
        self.actionableAdvice = actionableAdvice
        self.observedMetricFormatted = observedMetricFormatted
    }
}

/// Granular statistical measurements of the user's historical charging habits.
struct ChargingHabitMetrics: Codable, Hashable {
    var totalSessions: Int
    var acSessionsCount: Int
    var dcSessionsCount: Int
    var acEnergyKWh: Double
    var dcEnergyKWh: Double
    var acEnergyRatio: Double
    var dcEnergyRatio: Double

    var sessionsWithPercentagesCount: Int
    var averageStartSoC: Double?
    var averageEndSoC: Double?
    var averageDeltaSoC: Double?

    var sessionsEndingAt100Count: Int
    var sessionsEndingAt100Percentage: Double
    var sessionsEndingAbove85Count: Int
    var sessionsEndingAbove85Percentage: Double

    var sessionsStartingBelow15Count: Int
    var sessionsStartingBelow15Percentage: Double
    var sessionsStartingBelow10Count: Int
    var sessionsStartingBelow10Percentage: Double

    var daysSinceLastFullCharge: Int?
    var lastFullChargeDate: Date?
}

/// Comprehensive analysis results of charging behavior, score, and recommendations.
struct ChargingBehaviorAnalysis: Identifiable, Hashable {
    var id: String { vehicleId }
    var vehicleId: String
    var vehicleName: String
    var chemistry: BatteryChemistry
    var overallScore: Double // 0 to 100
    var grade: ChargingBehaviorGrade
    var assessment: ChargingLongevityAssessment
    var summaryText: String

    // Dimension sub-scores (0 to 100)
    var speedBalanceScore: Double
    var targetSoCScore: Double
    var dischargeBufferScore: Double
    var cycleConsistencyScore: Double

    var metrics: ChargingHabitMetrics
    var recommendations: [ChargingRecommendation]

    init(
        vehicleId: String,
        vehicleName: String,
        chemistry: BatteryChemistry,
        overallScore: Double,
        grade: ChargingBehaviorGrade,
        assessment: ChargingLongevityAssessment,
        summaryText: String,
        speedBalanceScore: Double,
        targetSoCScore: Double,
        dischargeBufferScore: Double,
        cycleConsistencyScore: Double,
        metrics: ChargingHabitMetrics,
        recommendations: [ChargingRecommendation]
    ) {
        self.vehicleId = vehicleId
        self.vehicleName = vehicleName
        self.chemistry = chemistry
        self.overallScore = min(100.0, max(0.0, overallScore))
        self.grade = grade
        self.assessment = assessment
        self.summaryText = summaryText
        self.speedBalanceScore = min(100.0, max(0.0, speedBalanceScore))
        self.targetSoCScore = min(100.0, max(0.0, targetSoCScore))
        self.dischargeBufferScore = min(100.0, max(0.0, dischargeBufferScore))
        self.cycleConsistencyScore = min(100.0, max(0.0, cycleConsistencyScore))
        self.metrics = metrics
        self.recommendations = recommendations
    }
}

/// Standardized best practice item for the educational charging guide.
struct ChargingBestPracticeItem: Identifiable, Hashable {
    var id: String
    var category: String
    var title: String
    var icon: String
    var color: Color
    var summary: String
    var bullets: [String]
    var chemistryApplicability: ChemistryApplicability

    enum ChemistryApplicability: String {
        case all = "All Chemistries"
        case lfpOnly = "LFP (Blade / Phosphate)"
        case nmcNcaOnly = "NMC & NCA Chemistries"
    }

    static let universalBestPractices: [ChargingBestPracticeItem] = [
        ChargingBestPracticeItem(
            id: "daily_target_nmc",
            category: "Daily Charge Limits",
            title: "NMC / NCA: Keep Daily Charging to 80%–90%",
            icon: "battery.75",
            color: .blue,
            summary: "Nickel-rich chemistry undergoes accelerated cathode electrolyte oxidation and mechanical lattice strain when kept above 90% State of Charge.",
            bullets: [
                "Set your vehicle's charge limit slider to 80% (or 90% maximum) for daily commutes.",
                "Charge to 100% only just before departing on long road trips.",
                "Avoid letting the car sit parked at 100% for days, especially in warm weather."
            ],
            chemistryApplicability: .nmcNcaOnly
        ),
        ChargingBestPracticeItem(
            id: "daily_target_lfp",
            category: "Daily Charge Limits",
            title: "LFP: Charge to 100% Regularly for BMS Calibration",
            icon: "battery.100.bolt",
            color: .green,
            summary: "Lithium Iron Phosphate (LFP) has an exceptionally flat voltage curve between 20% and 90%, making voltage-based SoC estimation prone to drift without regular 100% top-offs.",
            bullets: [
                "Charge your LFP vehicle to 100% at least once every 1 to 2 weeks.",
                "Charging to 100% allows the Battery Management System (BMS) to perform passive cell balancing.",
                "LFP has superior thermal stability and suffers far less degradation from full charges compared to NMC."
            ],
            chemistryApplicability: .lfpOnly
        ),
        ChargingBestPracticeItem(
            id: "charging_speed",
            category: "AC vs. DC Speed",
            title: "Prioritize AC Slow Charging for Daily Driving",
            icon: "powerplug.fill",
            color: .blue,
            summary: "Gentle AC charging (7–11 kW) minimizes internal cell heating, prevents lithium dendrite plating, and preserves the Solid Electrolyte Interphase (SEI) layer.",
            bullets: [
                "Rely on Home or Work AC chargers for >= 70% of your total energy intake.",
                "Reserve high-power DC Fast Chargers (50–350 kW) for long road trips where quick turnaround is essential.",
                "Whenever possible, avoid consecutive DC rapid charges in high ambient heat without cool-down intervals."
            ],
            chemistryApplicability: .all
        ),
        ChargingBestPracticeItem(
            id: "low_soc_buffer",
            category: "Discharge Buffer",
            title: "Avoid Deep Discharges Below 10%–15%",
            icon: "battery.25",
            color: .orange,
            summary: "Allowing lithium cells to drop below 10% increases internal resistance, generates copper dissolution risk on negative current collectors, and puts stress on individual weaker cells.",
            bullets: [
                "Plug in when your battery reaches 15%–20% during normal day-to-day driving.",
                "Never leave your vehicle parked at < 5% State of Charge for extended hours.",
                "If running very low in cold conditions, charge immediately while the pack is still warm from driving."
            ],
            chemistryApplicability: .all
        ),
        ChargingBestPracticeItem(
            id: "temperature_preconditioning",
            category: "Thermal Management",
            title: "Precondition Battery Before DC Fast Charging",
            icon: "thermometer.sun.fill",
            color: .red,
            summary: "Cold lithium cells have high internal resistance and cannot accept high charging currents safely, while overheated cells degrade rapidly.",
            bullets: [
                "Use built-in vehicle navigation to navigate to fast chargers so the BMS automatically pre-heats/cools the pack.",
                "Avoid aggressive DC fast charging immediately after leaving the car in freezing temperatures.",
                "In hot climates, try to charge in shaded areas or covered parking garages when feasible."
            ],
            chemistryApplicability: .all
        ),
        ChargingBestPracticeItem(
            id: "long_term_storage",
            category: "Storage & Inactivity",
            title: "Store at 40%–60% SoC for Extended Inactivity",
            icon: "parkingsign.circle.fill",
            color: .purple,
            summary: "Storing an EV battery at extreme charge levels (0% or 100%) for weeks accelerates calendar degradation and irreversible capacity loss.",
            bullets: [
                "If leaving your car unused for more than 2 weeks, set SoC to approximately 50%.",
                "Keep the vehicle plugged into a slow charger with the target set to 50% so auxiliary systems don't drain the 12V battery.",
                "Store in a temperature-moderate garage if possible to avoid extreme seasonal thermal extremes."
            ],
            chemistryApplicability: .all
        )
    ]
}
