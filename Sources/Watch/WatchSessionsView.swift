import SwiftUI

/// Page three: the most recent charges.
struct WatchSessionsView: View {
    let snapshot: JouleSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WatchTheme.brandGradient)
                    Text("Recent Charges")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                if snapshot.recentSessions.isEmpty {
                    Text("No charging sessions logged yet.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.recentSessions) { session in
                        row(session)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(WatchTheme.brandGradient.opacity(0.2), for: .tabView)
    }

    private func row(_ session: JouleSnapshot.SessionSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: WatchTheme.chargeIcon(isDC: session.isDC))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(WatchTheme.chargeColor(isDC: session.isDC))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(session.displayLocation)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("\(SnapshotFormat.energy(session.energyAdded)) · \(SnapshotFormat.relativeDate(session.date))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Text(snapshot.currency.format(session.totalPrice))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
