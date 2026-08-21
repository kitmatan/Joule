import SwiftUI

/// Page one: what this month has cost.
struct WatchOverviewView: View {
    let snapshot: JouleSnapshot

    @EnvironmentObject private var store: WatchSnapshotStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header

                Text(snapshot.currency.format(snapshot.monthCost))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("\(SnapshotFormat.energy(snapshot.monthEnergy)) · \(snapshot.monthSessionCount) \(snapshot.monthSessionCount == 1 ? "charge" : "charges")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if snapshot.monthSavings > 0 {
                    savingsBadge
                }

                metrics

                refreshButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(WatchTheme.brandGradient.opacity(0.28), for: .tabView)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.car.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(WatchTheme.brandGradient)
            Text(snapshot.vehicleName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var savingsBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: String(localized: "Saved %@"), snapshot.currency.format(snapshot.monthSavings)))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.18), in: Capsule())
    }

    @ViewBuilder
    private var metrics: some View {
        VStack(spacing: 5) {
            if snapshot.averagePricePerKWh > 0 {
                WatchMetricRow(
                    icon: "tag.fill",
                    color: .orange,
                    title: "Avg rate",
                    value: snapshot.currency.formatRate(snapshot.averagePricePerKWh)
                )
            }

            if snapshot.hasDrivingData, snapshot.efficiencyKmPerKWh > 0 {
                WatchMetricRow(
                    icon: "gauge.with.needle.fill",
                    color: .mint,
                    title: "Efficiency",
                    value: SnapshotFormat.efficiency(kmPerKWh: snapshot.efficiencyKmPerKWh, unitSystem: snapshot.unitSystem)
                )
            }

            if let last = snapshot.lastSession {
                WatchMetricRow(
                    icon: WatchTheme.chargeIcon(isDC: last.isDC),
                    color: WatchTheme.chargeColor(isDC: last.isDC),
                    title: "Last charge",
                    value: SnapshotFormat.energy(last.energyAdded),
                    detail: SnapshotFormat.relativeDate(last.date)
                )
            }
        }
        .padding(.top, 2)
    }

    private var refreshButton: some View {
        Button {
            Task { await store.refresh() }
        } label: {
            if store.isRefreshing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .disabled(store.isRefreshing)
        .padding(.top, 4)
    }
}
