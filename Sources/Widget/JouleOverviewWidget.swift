import WidgetKit
import SwiftUI

/// The main widget: what this month has cost, and what it saved against petrol.
struct JouleOverviewWidget: Widget {
    static let kind = "JouleOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotTimelineProvider()) { entry in
            JouleOverviewWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Charging Overview")
        .description("This month's charging spend, energy, and savings versus petrol.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular
        ])
    }
}

struct JouleOverviewWidgetView: View {
    let entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(URL(string: "\(SharedStorage.urlScheme)://dashboard"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            AccessorySpendCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AccessoryOverviewRectangularView(snapshot: entry.snapshot, isUnconfigured: entry.isUnconfigured)
        case .accessoryInline:
            AccessoryOverviewInlineView(snapshot: entry.snapshot)
        case .systemMedium:
            if entry.isUnconfigured {
                WidgetUnconfiguredView()
            } else {
                MediumOverviewView(snapshot: entry.snapshot)
            }
        default:
            if entry.isUnconfigured {
                WidgetUnconfiguredView(compact: true)
            } else {
                SmallOverviewView(snapshot: entry.snapshot)
            }
        }
    }
}

// MARK: - Small

private struct SmallOverviewView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.brandGradient)
                Text(snapshot.generatedAt.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            // The headline number gets the whole width and the rounded face used by the app's
            // hero card, so the two surfaces read as the same product.
            Text(snapshot.currency.format(snapshot.monthCost))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("\(SnapshotFormat.energy(snapshot.monthEnergy)) · \(snapshot.monthSessionCount) \(snapshot.monthSessionCount == 1 ? "charge" : "charges")")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Savings is the more motivating figure, but it only exists once there's enough data to
    /// model a petrol baseline; battery health is the fallback, and the vehicle name the last resort.
    @ViewBuilder
    private var footer: some View {
        if snapshot.monthSavings > 0 {
            badge(
                icon: "leaf.fill",
                text: "Saved \(SnapshotFormat.compactCurrency(snapshot.monthSavings, currency: snapshot.currency))",
                color: WidgetTheme.savingsColor
            )
        } else if let health = snapshot.batteryHealth {
            badge(
                icon: "bolt.batteryblock.fill",
                text: "\(SnapshotFormat.stateOfHealth(health.stateOfHealth)) SoH",
                color: WidgetTheme.healthColor(for: health.stateOfHealth)
            )
        } else {
            Text(snapshot.vehicleName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Medium

private struct MediumOverviewView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leftColumn
            Divider()
            rightColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.brandGradient)
                Text(snapshot.vehicleName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            Text(snapshot.currency.format(snapshot.monthCost))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("\(snapshot.generatedAt.formatted(.dateTime.month(.wide))) · \(SnapshotFormat.energy(snapshot.monthEnergy))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            MonthlyCostSparkline(months: snapshot.monthlyCosts, currency: snapshot.currency)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let health = snapshot.batteryHealth {
                metric(
                    icon: "bolt.batteryblock.fill",
                    color: WidgetTheme.healthColor(for: health.stateOfHealth),
                    title: "Battery",
                    value: SnapshotFormat.stateOfHealth(health.stateOfHealth),
                    unit: "SoH"
                )
            }

            if snapshot.monthSavings > 0 {
                metric(
                    icon: "leaf.fill",
                    color: WidgetTheme.savingsColor,
                    title: "Saved",
                    value: SnapshotFormat.compactCurrency(snapshot.monthSavings, currency: snapshot.currency),
                    unit: "vs. petrol"
                )
            }

            if snapshot.hasDrivingData, snapshot.efficiencyKmPerKWh > 0 {
                metric(
                    icon: "gauge.with.needle.fill",
                    color: .mint,
                    title: "Efficiency",
                    value: String(format: "%.1f", snapshot.unitSystem.convertFromKm(snapshot.efficiencyKmPerKWh)),
                    unit: snapshot.unitSystem.efficiencyUnit
                )
            } else if let last = snapshot.lastSession {
                metric(
                    icon: WidgetTheme.chargeIcon(isDC: last.isDC),
                    color: WidgetTheme.chargeColor(isDC: last.isDC),
                    title: "Last charge",
                    value: SnapshotFormat.energy(last.energyAdded, includeUnit: false),
                    unit: "kWh · \(SnapshotFormat.relativeDate(last.date))"
                )
            }

            Spacer(minLength: 0)
        }
        .frame(width: 116, alignment: .leading)
    }

    private func metric(icon: String, color: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
