import SwiftUI
import WidgetKit

// Accessory families are shared verbatim between the iPhone Lock Screen and Apple Watch
// complications — same sizes, same rendering modes, same one-tint constraint. Writing them once
// keeps the two surfaces from drifting apart as the design changes.

// MARK: - Circular

/// State of health as a ring. A gauge is the right form here: the value is a bounded percentage,
/// and the ring reads at a glance without needing the digits to be legible at 26pt.
struct AccessoryHealthCircularView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        if let health = snapshot.batteryHealth {
            Gauge(value: healthFraction(health.stateOfHealth), in: 0...1) {
                Image(systemName: "bolt.batteryblock.fill")
            } currentValueLabel: {
                Text(SnapshotFormat.stateOfHealth(health.stateOfHealth))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .minimumScaleFactor(0.7)
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        } else {
            AccessoryUnavailableCircularView(icon: "bolt.batteryblock.fill")
        }
    }

    /// Rebased to 70–100%: a pack below 70% SoH is beyond end-of-warranty for every chemistry
    /// Joule supports, so spending 70% of the ring on states no user will see would leave real
    /// degradation almost invisible.
    private func healthFraction(_ soh: Double) -> Double {
        min(1, max(0, (soh - 70) / 30))
    }
}

/// This month's spend, for users who care more about cost than battery wear.
struct AccessorySpendCircularView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(SnapshotFormat.compactCurrency(snapshot.monthCost, currency: snapshot.currency))
                    .font(.system(size: 14, design: .rounded).weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(2)
        }
        .widgetAccentable()
    }
}

struct AccessoryUnavailableCircularView: View {
    let icon: String

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text("—")
                    .font(.system(size: 13, design: .rounded).weight(.semibold))
            }
        }
        .widgetAccentable()
    }
}

// MARK: - Rectangular

struct AccessoryOverviewRectangularView: View {
    let snapshot: JouleSnapshot
    let isUnconfigured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if isUnconfigured {
                Text("Joule")
                    .font(.headline)
                    .widgetAccentable()
                Text("Open to start tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.car.fill")
                        .font(.caption2)
                    Text(monthLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .widgetAccentable()

                Text(snapshot.currency.format(snapshot.monthCost))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var monthLabel: String {
        snapshot.generatedAt.formatted(.dateTime.month(.wide))
    }

    /// Energy is the reliable line; savings and SoH are only shown once they exist, so the row
    /// never reads as a broken value.
    private var subtitle: String {
        var parts: [String] = [SnapshotFormat.energy(snapshot.monthEnergy)]
        if let health = snapshot.batteryHealth {
            parts.append("\(SnapshotFormat.stateOfHealth(health.stateOfHealth)) SoH")
        } else if snapshot.monthSavings > 0 {
            parts.append("saved \(SnapshotFormat.compactCurrency(snapshot.monthSavings, currency: snapshot.currency))")
        }
        return parts.joined(separator: " · ")
    }
}

struct AccessoryHealthRectangularView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.caption2)
                Text("Battery Health")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .widgetAccentable()

            if let health = snapshot.batteryHealth {
                Text("\(SnapshotFormat.stateOfHealth(health.stateOfHealth)) SoH")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(health.assessmentTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Calibrating")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text("Log start and end charge %")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Inline

struct AccessoryOverviewInlineView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        // The inline slot renders as a single tinted string beside the time; a Label is the only
        // structure the system honours here.
        Label {
            Text(text)
        } icon: {
            Image(systemName: "bolt.car.fill")
        }
    }

    private var text: String {
        if let health = snapshot.batteryHealth {
            return "\(snapshot.currency.format(snapshot.monthCost)) · \(SnapshotFormat.stateOfHealth(health.stateOfHealth)) SoH"
        }
        return "\(snapshot.currency.format(snapshot.monthCost)) this month"
    }
}

// MARK: - Corner (watchOS)

#if os(watchOS)
/// The corner family curves its label around the bezel; the system supplies the curvature, so the
/// view only provides a compact glyph plus the text to bend.
struct AccessoryHealthCornerView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "bolt.batteryblock.fill")
                .font(.title3)
                .widgetAccentable()
        }
        .widgetLabel {
            if let health = snapshot.batteryHealth {
                Text("\(SnapshotFormat.stateOfHealth(health.stateOfHealth)) SoH")
            } else {
                Text(snapshot.currency.format(snapshot.monthCost))
            }
        }
    }
}
#endif
