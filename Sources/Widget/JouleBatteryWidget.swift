import WidgetKit
import SwiftUI

/// Battery health at a glance, deep-linking into the Battery Health tab.
struct JouleBatteryWidget: Widget {
    static let kind = "JouleBatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotTimelineProvider()) { entry in
            JouleBatteryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Battery Health")
        .description("Estimated State of Health and usable capacity for your EV.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct JouleBatteryWidgetView: View {
    let entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(URL(string: "\(SharedStorage.urlScheme)://battery"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            AccessoryHealthCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AccessoryHealthRectangularView(snapshot: entry.snapshot)
        default:
            if entry.isUnconfigured {
                WidgetUnconfiguredView(compact: true)
            } else {
                SmallBatteryView(snapshot: entry.snapshot)
            }
        }
    }
}

private struct SmallBatteryView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        if let health = snapshot.batteryHealth {
            healthy(health)
        } else {
            calibrating
        }
    }

    private func healthy(_ health: JouleSnapshot.BatteryHealthSnapshot) -> some View {
        let tint = WidgetTheme.healthColor(for: health.stateOfHealth)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(snapshot.vehicleName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", health.stateOfHealth))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(health.assessmentTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 6)

            // The bar restates the percentage in a form that survives being glanced at, on the
            // same 70–100% scale as the circular gauge.
            capacityBar(health: health, tint: tint)

            Text("\(String(format: "%.1f", health.capacityKWh)) of \(String(format: "%.0f", snapshot.nominalCapacityKWh)) kWh")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func capacityBar(health: JouleSnapshot.BatteryHealthSnapshot, tint: Color) -> some View {
        GeometryReader { geometry in
            let fraction = min(1, max(0, (health.stateOfHealth - 70) / 30))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.2))
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geometry.size.width * fraction))
            }
        }
        .frame(height: 5)
    }

    private var calibrating: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "bolt.batteryblock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WidgetTheme.brandGradient)

            Text("Calibrating")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text("Log a charge with start and end battery % to estimate State of Health.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
