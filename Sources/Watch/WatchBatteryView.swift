import SwiftUI

/// Page two: battery State of Health.
struct WatchBatteryView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        ScrollView {
            if let health = snapshot.batteryHealth {
                healthContent(health)
            } else {
                calibratingContent
            }
        }
        .containerBackground(tint.opacity(0.28).gradient, for: .tabView)
    }

    private var tint: Color {
        WatchTheme.healthColor(for: snapshot.batteryHealth?.stateOfHealth ?? 100)
    }

    private func healthContent(_ health: JouleSnapshot.BatteryHealthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                Text("Battery Health")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // The gauge covers 70–100%: below that a pack is out of warranty on every chemistry
            // Joule models, so the lower range would only ever be dead space.
            Gauge(value: min(1, max(0, (health.stateOfHealth - 70) / 30))) {
                EmptyView()
            } currentValueLabel: {
                Text(String(format: "%.1f%%", health.stateOfHealth))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(tint)
            .frame(maxWidth: .infinity)

            Text(health.assessmentTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            VStack(spacing: 5) {
                WatchMetricRow(
                    icon: "battery.100",
                    color: tint,
                    title: "Usable capacity",
                    value: String(format: "%.1f kWh", health.capacityKWh),
                    detail: String(format: "of %.0f", snapshot.nominalCapacityKWh)
                )

                if let range = health.projectedRangeKm {
                    WatchMetricRow(
                        icon: "road.lanes",
                        color: .purple,
                        title: "Projected range",
                        value: snapshot.unitSystem.formatDistance(km: range)
                    )
                }

                WatchMetricRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .teal,
                    title: "Full cycles",
                    value: String(format: "%.1f", health.equivalentFullCycles)
                )
            }

            if !health.isCalibrated {
                Text("Degradation rate still calibrating — log more charges with start and end %.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calibratingContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.batteryblock.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(WatchTheme.brandGradient)

            Text("Calibrating")
                .font(.headline)

            Text("Log a charge with start and end battery % on your iPhone to estimate State of Health.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
