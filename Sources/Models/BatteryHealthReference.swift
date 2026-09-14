import Foundation
import SwiftUI

/// Where an externally measured State of Health figure came from.
///
/// Raw values are persisted with the vehicle, so they must stay stable — the user-facing wording
/// lives in `displayName`.
enum BatteryReferenceSource: String, Codable, CaseIterable, Identifiable {
    case dealer = "Dealer"
    case independent = "Independent Shop"
    case obdScan = "OBD Scan"
    case inspection = "Inspection Report"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .dealer: return "Dealer Service"
        case .independent: return "Independent Shop"
        case .obdScan: return "OBD Scan"
        case .inspection: return "Inspection Report"
        }
    }

    var icon: String {
        switch self {
        case .dealer: return "building.2.fill"
        case .independent: return "wrench.and.screwdriver.fill"
        case .obdScan: return "cable.connector"
        case .inspection: return "doc.text.magnifyingglass"
        }
    }
}

/// A State of Health figure measured outside the app — a dealer BMS readout, an OBD scan, or a
/// third-party inspection report.
///
/// Deliberately kept apart from `BatteryHealthDataPoint`. The app's own SoH is a charger-side
/// energy estimate: wall energy times an assumed charging efficiency, divided by ΔSoC. A service
/// tool instead reports the pack's internal capacity model, commonly against *gross* rather than
/// usable capacity, and usually quantised to whole percent. They are different measurands with
/// different error budgets, so the two are displayed side by side and never averaged, reconciled,
/// or substituted for one another.
struct BatteryHealthReference: Identifiable, Codable, Hashable {
    var id: String
    /// The date the reading was taken — not the date it was entered into the app.
    var date: Date
    var sohPercent: Double
    var odometerKm: Double?
    var source: BatteryReferenceSource
    /// Diagnostic tool or workshop name, for the certificate's audit trail.
    var toolName: String?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        date: Date,
        sohPercent: Double,
        odometerKm: Double? = nil,
        source: BatteryReferenceSource = .dealer,
        toolName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.sohPercent = sohPercent
        self.odometerKm = odometerKm
        self.source = source
        self.toolName = toolName
        self.notes = notes
    }
}

/// A service reading paired with the app's own smoothed estimate interpolated to the *same date*.
///
/// Comparing a September reading against today's estimate would manufacture a disagreement out of
/// nothing but elapsed time, so the estimate is always evaluated at the reading's own date.
struct BatteryReferenceComparison: Hashable {
    let reference: BatteryHealthReference

    /// The app's smoothed SoH interpolated to `reference.date`, or `nil` when the charging history
    /// does not reach that date closely enough to support a fair comparison.
    let estimatedSoHAtReadingDate: Double?

    /// Reading minus estimate, in percentage points. Positive means the service tool read higher.
    var delta: Double? {
        guard let estimate = estimatedSoHAtReadingDate else { return nil }
        return reference.sohPercent - estimate
    }

    /// Spread the two methods can differ by before the gap needs explaining, in percentage points.
    ///
    /// The assumed AC/DC efficiency constant propagates into the app's SoH very nearly one-for-one,
    /// and a service tool quoting gross rather than usable capacity shifts its figure again. A few
    /// points of disagreement is the expected state of the world, not a defect in either number.
    static let expectedOffsetTolerance: Double = 3.0

    enum Agreement {
        /// The gap is no larger than routine methodology differences account for.
        case withinExpectedOffset
        /// Large enough that the nominal capacity or efficiency settings are worth a look.
        case exceedsExpectedOffset
        /// No overlapping charging history, so no honest comparison can be drawn.
        case notComparable
    }

    var agreement: Agreement {
        guard let delta else { return .notComparable }
        return abs(delta) <= Self.expectedOffsetTolerance ? .withinExpectedOffset : .exceedsExpectedOffset
    }
}
