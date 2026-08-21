import SwiftUI

/// Visual tokens shared by the widgets, matching `DashboardHeroCard`'s blue→teal identity.
///
/// Accessory families (lock screen and watch complications) are rendered by the system in a
/// single tint — `vibrant` and `accented` modes discard color entirely — so anything that relies
/// on hue to carry meaning has to carry it a second way there. The values below are used for the
/// system families; the accessory views lean on weight, shape, and labels instead.
enum WidgetTheme {
    static let accent = Color.blue
    static let accentSecondary = Color.teal

    static let brandGradient = LinearGradient(
        colors: [Color.blue, Color.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let savingsColor = Color.green

    /// Health banding mirrors `BatteryHealthSummary.assessment` so the widget and the in-app chip
    /// never disagree about whether a battery is doing well.
    static func healthColor(for soh: Double) -> Color {
        if soh >= 95 { return .green }
        if soh >= 90 { return .mint }
        if soh >= 82 { return .orange }
        return .red
    }

    static func chargeColor(isDC: Bool) -> Color {
        isDC ? .orange : .blue
    }

    static func chargeIcon(isDC: Bool) -> String {
        isDC ? "bolt.fill" : "powerplug.fill"
    }
}

/// The empty state used across every family when no snapshot has been published.
struct WidgetUnconfiguredView: View {
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "bolt.car.fill")
                .font(.system(size: compact ? 16 : 22, weight: .semibold))
                .foregroundStyle(WidgetTheme.brandGradient)

            Text("Joule")
                .font(.headline)
                .fontWeight(.bold)

            Text("Open the app to start tracking your charging.")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
