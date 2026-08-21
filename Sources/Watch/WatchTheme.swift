import SwiftUI

/// Watch-side visual tokens. Kept separate from `WidgetTheme` because the watch app target does
/// not include the widget sources, but the values are deliberately identical so the app and its
/// complications look like one product.
enum WatchTheme {
    static let brandGradient = LinearGradient(
        colors: [Color.blue, Color.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

/// A titled block with a large rounded value — the watch equivalent of the app's metric tile.
struct WatchMetricRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    var detail: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 0)

            if let detail {
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(Color.gray.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
