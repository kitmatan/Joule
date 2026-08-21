import SwiftUI

/// Six months of charging spend, as a bare column sparkline.
///
/// Deliberately not a Swift Chart: at six bars with no axes, no legend, and no interaction, the
/// framework's layout machinery buys nothing and costs render time in a memory-capped extension.
/// Plain shapes also give exact control over the spacing and the flat baseline, which is what
/// makes a row of small bars readable.
///
/// One series, so no legend — the surrounding card names the measure. Only the current month is
/// labelled; a number over every bar would out-shout the shape that carries the trend.
struct MonthlyCostSparkline: View {
    let months: [JouleSnapshot.MonthlyCostSnapshot]
    let currency: AppCurrency

    /// Bars are drawn against the largest month in view, so the shape shows relative spend rather
    /// than absolute — the axis label supplies the scale.
    private var peak: Double {
        max(months.map(\.cost).max() ?? 0, 1)
    }

    private var currentMonth: JouleSnapshot.MonthlyCostSnapshot? {
        months.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(months) { month in
                    bar(for: month)
                }
            }
            .frame(height: 28)

            HStack(spacing: 3) {
                ForEach(months) { month in
                    Text(SnapshotFormat.shortMonth(month.month))
                        .font(.system(size: 8, weight: .medium))
                        // The current month is the reader's anchor; the rest are context.
                        .foregroundStyle(isCurrent(month) ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monthly charging cost")
        .accessibilityValue(accessibilitySummary)
    }

    private func bar(for month: JouleSnapshot.MonthlyCostSnapshot) -> some View {
        GeometryReader { geometry in
            let fraction = month.cost / peak
            // A month with no charging still gets a hairline so the gap reads as "nothing spent"
            // rather than as a rendering fault.
            let height = month.cost > 0
                ? max(3, geometry.size.height * fraction)
                : 1.5

            VStack {
                Spacer(minLength: 0)
                UnevenRoundedRectangle(
                    topLeadingRadius: 2,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 2,
                    style: .continuous
                )
                .fill(isCurrent(month) ? AnyShapeStyle(WidgetTheme.brandGradient) : AnyShapeStyle(WidgetTheme.accent.opacity(0.28)))
                .frame(height: height)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func isCurrent(_ month: JouleSnapshot.MonthlyCostSnapshot) -> Bool {
        month.month == currentMonth?.month
    }

    private var accessibilitySummary: String {
        months
            .map { "\(SnapshotFormat.shortMonth($0.month)) \(currency.format($0.cost))" }
            .joined(separator: ", ")
    }
}
