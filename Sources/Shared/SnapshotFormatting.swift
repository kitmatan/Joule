import Foundation

/// Formatting shared by the widgets and the watch app.
///
/// The in-app formatters in `AppCurrency` are tuned for a full-width card; a lock screen
/// accessory or a 41mm complication has room for roughly six glyphs. These variants trade
/// precision for fit, which is the right call when the number is a glanceable summary and the
/// exact figure is one tap away in the app.
enum SnapshotFormat {

    /// Currency with the decimals dropped once the amount no longer needs them, then abbreviated
    /// past four digits ("฿1,285" → "฿14.9k"). Small amounts keep their decimals, since "฿5"
    /// where "฿4.69" was meant is a materially different number to the reader.
    static func compactCurrency(_ amount: Double, currency: AppCurrency) -> String {
        let magnitude = abs(amount)
        let sign = amount < 0 ? "-" : ""

        if magnitude >= 10_000 {
            return String(format: "%@%@%.1fk", sign, currency.symbol, magnitude / 1_000)
        }
        if magnitude >= 100 {
            return "\(sign)\(currency.symbol)\(Int(magnitude.rounded()).formatted(.number.grouping(.automatic)))"
        }
        return String(format: "%@%@%.2f", sign, currency.symbol, magnitude)
    }

    /// Energy sized to the space available: "262 kWh" once past three digits, "32.4 kWh" below.
    static func energy(_ kWh: Double, includeUnit: Bool = true) -> String {
        let unit = includeUnit ? " kWh" : ""
        if abs(kWh) >= 100 {
            return "\(Int(kWh.rounded()))\(unit)"
        }
        return String(format: "%.1f%@", kWh, unit)
    }

    /// State of health as a whole percentage — the fractional part is well inside the
    /// estimator's own error bars, so showing it would imply precision that isn't there.
    static func stateOfHealth(_ soh: Double) -> String {
        String(format: "%.0f%%", soh)
    }

    /// Driving efficiency in the active unit system.
    static func efficiency(kmPerKWh: Double, unitSystem: UnitSystem) -> String {
        guard kmPerKWh > 0 else { return "—" }
        return String(format: "%.1f %@", unitSystem.convertFromKm(kmPerKWh), unitSystem.efficiencyUnit)
    }

    /// "2h ago", "Yesterday", "12 Mar" — whichever is shortest for the age of the session.
    ///
    /// Every comparison is made against `reference` rather than the wall clock. `isDateInToday`
    /// and friends would silently ignore the parameter, which makes the function untestable and
    /// wrong for any caller rendering a timeline entry for a moment other than now.
    static func relativeDate(_ date: Date, reference: Date = Date()) -> String {
        let calendar = Calendar.current
        let interval = reference.timeIntervalSince(date)

        if interval < 60 { return String(localized: "Just now") }
        if interval < 3_600 { return String(format: "%dm ago", Int(interval / 60)) }

        if calendar.isDate(date, inSameDayAs: reference) {
            return String(format: "%dh ago", Int(interval / 3_600))
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: reference),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday")
        }

        if let days = calendar.dateComponents([.day], from: date, to: reference).day, days < 7 {
            return String(format: "%dd ago", days)
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Month label for the sparkline axis ("Mar").
    static func shortMonth(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated))
    }
}
