import Foundation

/// The read-only view of the user's charging data that the widgets and the watch app render.
///
/// The app's own `ChargingSession` cannot cross a target boundary: it carries Firestore's
/// `@DocumentID`, and Firestore ships no watchOS slice at all. Rather than link Firebase into three
/// extra targets to redisplay a handful of numbers, the app computes everything once and publishes
/// this plain `Codable` value. Extensions therefore stay dependency-free and cannot drift from the
/// dashboard's arithmetic — there is only one implementation of it, in `ChargingStatistics`.
struct JouleSnapshot: Codable, Equatable, Sendable {
    /// Bumped whenever the shape changes so a stale payload from an older build is discarded
    /// rather than decoded into misleading zeros.
    static let currentVersion = 1

    var version: Int = JouleSnapshot.currentVersion
    var generatedAt: Date

    // MARK: - Vehicle

    var vehicleName: String
    var vehicleCount: Int
    /// Chemistry label ("LFP", "NMC", …) shown on the larger widget families.
    var chemistry: String
    var nominalCapacityKWh: Double

    // MARK: - Formatting context

    /// Stored as raw values so the snapshot stays decodable even if a case is added later.
    var currencyCode: String
    var unitSystemRaw: String

    var currency: AppCurrency { AppCurrency.from(code: currencyCode) }
    var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    // MARK: - Spend

    var monthCost: Double
    var monthEnergy: Double
    var monthSessionCount: Int
    var monthSavings: Double

    var totalCost: Double
    var totalEnergy: Double
    var totalSessionCount: Int
    var lifetimeSavings: Double

    // MARK: - Rates & efficiency

    /// Lifetime average charging price per kWh. Zero when no energy has been logged.
    var averagePricePerKWh: Double
    /// Driving efficiency in km/kWh — always metric base, converted at render time.
    var efficiencyKmPerKWh: Double
    /// Cost per distance unit, already expressed in the active unit system.
    var costPerDistance: Double
    var hasDrivingData: Bool

    // MARK: - Battery health

    var batteryHealth: BatteryHealthSnapshot?

    // MARK: - History

    var lastSession: SessionSnapshot?
    /// Newest first, capped by `ChargingStatistics.recentSessionLimit`.
    var recentSessions: [SessionSnapshot]
    /// Trailing months, oldest first, for the widget sparkline.
    var monthlyCosts: [MonthlyCostSnapshot]

    // MARK: - Nested types

    struct BatteryHealthSnapshot: Codable, Equatable, Sendable {
        var stateOfHealth: Double
        var capacityKWh: Double
        var assessmentTitle: String
        var projectedRangeKm: Double?
        var equivalentFullCycles: Double
        /// False while the regression has too little history to state a degradation rate.
        var isCalibrated: Bool

        /// Mirrors `BatteryHealthSummary`'s banding so widget tint matches the app's chip.
        var isHealthy: Bool { stateOfHealth >= 90 }
    }

    struct SessionSnapshot: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var date: Date
        var locationName: String?
        var energyAdded: Double
        var totalPrice: Double
        var endPercentage: Double?
        var isDC: Bool

        var displayLocation: String {
            guard let locationName, !locationName.trimmingCharacters(in: .whitespaces).isEmpty else {
                return isDC ? String(localized: "DC Charge") : String(localized: "AC Charge")
            }
            return locationName
        }
    }

    struct MonthlyCostSnapshot: Codable, Equatable, Identifiable, Sendable {
        var id: Date { month }
        var month: Date
        var cost: Double
        var energy: Double
    }

    // MARK: - Derived display state

    /// True when the user has never logged anything, so widgets can show an invitation
    /// instead of a wall of zeros.
    var isEmpty: Bool { totalSessionCount == 0 }

    // MARK: - Fixtures

    /// Neutral content for the widget gallery and SwiftUI previews.
    static let placeholder = JouleSnapshot(
        generatedAt: Date(),
        vehicleName: "GAC AION V",
        vehicleCount: 1,
        chemistry: "LFP",
        nominalCapacityKWh: 75.2,
        currencyCode: AppCurrency.thb.code,
        unitSystemRaw: UnitSystem.metric.rawValue,
        monthCost: 1_284.50,
        monthEnergy: 262.4,
        monthSessionCount: 7,
        monthSavings: 1_842.00,
        totalCost: 14_920.00,
        totalEnergy: 3_180.6,
        totalSessionCount: 84,
        lifetimeSavings: 21_460.00,
        averagePricePerKWh: 4.69,
        efficiencyKmPerKWh: 6.2,
        costPerDistance: 0.76,
        hasDrivingData: true,
        batteryHealth: BatteryHealthSnapshot(
            stateOfHealth: 97.4,
            capacityKWh: 73.2,
            assessmentTitle: "Excellent Health",
            projectedRangeKm: 486,
            equivalentFullCycles: 42.3,
            isCalibrated: true
        ),
        lastSession: SessionSnapshot(
            id: "placeholder-latest",
            date: Date().addingTimeInterval(-7_200),
            locationName: "Home",
            energyAdded: 32.4,
            totalPrice: 152.00,
            endPercentage: 80,
            isDC: false
        ),
        recentSessions: [],
        monthlyCosts: []
    )

    /// The zero state used before the app has ever published, and when the App Group is
    /// unreachable. Distinguished from `placeholder` so widgets render the onboarding copy.
    static let empty = JouleSnapshot(
        generatedAt: .distantPast,
        vehicleName: "Joule",
        vehicleCount: 0,
        chemistry: "",
        nominalCapacityKWh: 0,
        currencyCode: AppCurrency.thb.code,
        unitSystemRaw: UnitSystem.metric.rawValue,
        monthCost: 0,
        monthEnergy: 0,
        monthSessionCount: 0,
        monthSavings: 0,
        totalCost: 0,
        totalEnergy: 0,
        totalSessionCount: 0,
        lifetimeSavings: 0,
        averagePricePerKWh: 0,
        efficiencyKmPerKWh: 0,
        costPerDistance: 0,
        hasDrivingData: false,
        batteryHealth: nil,
        lastSession: nil,
        recentSessions: [],
        monthlyCosts: []
    )
}
