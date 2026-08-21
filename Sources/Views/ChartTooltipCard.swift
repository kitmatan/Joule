import SwiftUI

/// Standard card container for chart hover/selection tooltips across all app graphs.
struct ChartTooltipCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    // The tooltip floats over plotted marks, so it needs a heavier shadow in dark
                    // mode where the card and the chart backdrop are close in luminance.
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)
    }
}

/// A compact key-value row for chart tooltip breakdowns.
struct ChartTooltipRow: View {
    let title: LocalizedStringKey
    let value: String
    var dotColor: Color? = nil
    var isBold: Bool = false

    init(title: LocalizedStringKey, value: String, dotColor: Color? = nil, isBold: Bool = false) {
        self.title = title
        self.value = value
        self.dotColor = dotColor
        self.isBold = isBold
    }

    init(title: String, value: String, dotColor: Color? = nil, isBold: Bool = false) {
        self.title = LocalizedStringKey(title)
        self.value = value
        self.dotColor = dotColor
        self.isBold = isBold
    }

    var body: some View {
        HStack(spacing: 5) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.caption2)
                .fontWeight(isBold ? .bold : .medium)
                .foregroundColor(.primary)
        }
    }
}

