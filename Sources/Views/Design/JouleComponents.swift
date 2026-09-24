import SwiftUI

// MARK: - Surfaces

extension View {
    /// A white card with a hairline border: the default container for grouped content.
    func jouleCard(padding: CGFloat? = 16, radius: CGFloat = 18) -> some View {
        self
            .padding(padding.map { EdgeInsets(top: $0, leading: $0, bottom: $0, trailing: $0) } ?? EdgeInsets())
            .background(Color.jouleSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.jouleLine, lineWidth: 1)
            )
    }

    /// A tinted callout panel (explanations, warnings, habit tips) with no border.
    func joulePanel(_ fill: Color, padding: CGFloat = 14, radius: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Paper background for a scrolling screen, including List and Form.
    func joulePage() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.joulePaper.ignoresSafeArea())
    }

    /// For screens that hide the navigation bar: paints paper behind the status bar so content
    /// scrolling up never runs under the clock.
    func jouleStatusBarBackdrop() -> some View {
        self.overlay(alignment: .top) {
            GeometryReader { proxy in
                Color.joulePaper
                    .frame(height: proxy.safeAreaInsets.top)
                    .offset(y: -proxy.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Labels

/// Small uppercase mono label that names a figure or a section.
struct JouleLabel: View {
    private let text: Text
    private let color: Color

    init(_ text: LocalizedStringKey, color: Color = .jouleMuted) {
        self.text = Text(text)
        self.color = color
    }

    /// For text that is already localized, e.g. built with `String(localized:)`.
    init(verbatim text: String, color: Color = .jouleMuted) {
        self.text = Text(verbatim: text)
        self.color = color
    }

    var body: some View {
        text
            .font(.jouleMono(11, relativeTo: .caption2).weight(.medium))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// Section title in the display face, with an optional trailing accessory.
struct JouleSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.jouleDisplay(22, relativeTo: .title2))
                .foregroundStyle(Color.jouleInk)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension JouleSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
    }
}

/// A capsule tag: status, payment state, "Active".
struct JouleTag: View {
    let text: LocalizedStringKey
    var foreground: Color = .jouleInk
    var background: Color = .jouleSunken

    init(_ text: LocalizedStringKey, foreground: Color = .jouleInk, background: Color = .jouleSunken) {
        self.text = text
        self.foreground = foreground
        self.background = background
    }

    var body: some View {
        Text(text)
            .font(.jouleText(12, relativeTo: .caption).weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }
}

/// Square AC/DC badge that leads a session row.
struct ChargeTypeBadge: View {
    let type: ChargingType?
    var size: CGFloat = 44

    var body: some View {
        Text(type?.rawValue ?? "—")
            .font(.jouleMono(size > 40 ? 13 : 12, relativeTo: .caption).weight(.medium))
            .foregroundStyle(type?.jouleOnSoft ?? .jouleMuted)
            .frame(width: size, height: size)
            .background(type?.jouleSoft ?? .jouleSunken, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityLabel(type.map { "\($0.rawValue) charging" } ?? "Charging type not recorded")
    }
}

// MARK: - Figures

/// A labelled figure: mono label, display value, optional caption beneath.
struct JouleStat: View {
    let label: LocalizedStringKey
    let value: String
    var caption: String? = nil
    var valueColor: Color = .jouleInk
    var valueSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            JouleLabel(label)
            Text(value)
                .font(.jouleDisplay(valueSize, relativeTo: .title2))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.jouleText(12, relativeTo: .caption))
                    .foregroundStyle(Color.jouleMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(caption.map { "\(value), \($0)" } ?? value)
    }
}

/// A money figure with the fractional part muted: "฿140" + ".00".
struct JouleAmount: View {
    let formatted: String
    var size: CGFloat = 72
    var color: Color = .jouleInk
    var fractionColor: Color = .jouleMuted

    var body: some View {
        let (whole, fraction) = split(formatted)
        (Text(whole).foregroundColor(color) + Text(fraction).foregroundColor(fractionColor))
            .font(.jouleDisplay(size, relativeTo: .largeTitle))
            .tracking(-size * 0.03)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel(formatted)
    }

    /// Splits at the last decimal separator only when two digits follow it, so "฿1,250" and
    /// grouped thousands are never mistaken for a fraction.
    private func split(_ s: String) -> (String, String) {
        let separator = Locale.current.decimalSeparator ?? "."
        guard let range = s.range(of: separator, options: .backwards) else { return (s, "") }
        let tail = s[range.upperBound...]
        let digits = tail.prefix { $0.isNumber }
        guard digits.count == 2 else { return (s, "") }
        return (String(s[..<range.lowerBound]), String(s[range.lowerBound...]))
    }
}

// MARK: - Gauges

/// The segmented battery: `cells` cells, filled to `fraction`, the boundary cell partly filled.
struct CellGauge: View {
    let fraction: Double
    var cells: Int = 20
    var height: CGFloat = 28
    var spacing: CGFloat = 3
    var fill: Color = .jouleVolt
    var track: Color = .jouleInverseTrack
    var cornerRadius: CGFloat = 3

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        let filled = clamped * Double(cells)
        HStack(spacing: spacing) {
            ForEach(0..<cells, id: \.self) { index in
                let level = min(max(filled - Double(index), 0), 1)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(track)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(fill)
                                .frame(width: proxy.size.width * level)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A slim bar showing a share of a whole: energy added versus pack size, price versus the dearest.
struct ShareBar: View {
    let fraction: Double
    var color: Color = .jouleAC
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.jouleSunken)
                Capsule()
                    .fill(color)
                    .frame(width: max(height, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// Segmented control drawn to match the rest of the app. Options are few and short.
struct JoulePillPicker<Value: Hashable>: View {
    let options: [(value: Value, title: LocalizedStringKey)]
    @Binding var selection: Value
    var fillsWidth: Bool = true
    var accessibilityTitle: LocalizedStringKey = ""

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isOn = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.jouleText(13, relativeTo: .footnote).weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isOn ? Color.jouleInk : Color.jouleInk2)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 38)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.jouleRaised)
                                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.jouleSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityTitle))
    }
}

/// Filter chip: ink when selected, outlined otherwise.
struct JouleChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.jouleText(13, relativeTo: .footnote).weight(.medium))
                .foregroundStyle(isSelected ? Color.joulePaper : Color.jouleInk)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isSelected ? Color.jouleInk : Color.jouleSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.jouleInk : Color.jouleLine, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Volt fill, ink outline: the one primary action on a screen.
struct JoulePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jouleText(16, relativeTo: .body).weight(.semibold))
            .foregroundStyle(Color.jouleOnVolt)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.jouleVolt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.jouleOnVolt, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

/// Outlined capsule for secondary actions in headers ("Certificate", "Vehicle").
struct JouleOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jouleText(14, relativeTo: .subheadline).weight(.medium))
            .foregroundStyle(Color.jouleInk)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Color.jouleSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.jouleLine, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Dashed full-width button for "add something here" slots.
struct JouleDashedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jouleText(15, relativeTo: .subheadline).weight(.medium))
            .foregroundStyle(Color.jouleInk2)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.jouleMuted.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A tappable settings-style row: title, trailing value, chevron.
struct JouleDisclosureRow: View {
    let title: LocalizedStringKey
    var value: String? = nil
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.jouleText(15))
                    .foregroundStyle(Color.jouleInk2)
                    .frame(width: 22)
            }
            Text(title)
                .font(.jouleText(15, relativeTo: .body).weight(.medium))
                .foregroundStyle(Color.jouleInk)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.jouleText(15, relativeTo: .body))
                    .foregroundStyle(Color.jouleMuted)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.jouleText(13).weight(.semibold))
                .foregroundStyle(Color.jouleMuted)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}
