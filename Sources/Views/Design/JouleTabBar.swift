import SwiftUI

/// Bottom bar for iPhone and iPad: four destinations around a centred "Log charge" button.
///
/// The system tab bar is hidden and this one is overlaid on the TabView. Each tab reserves the
/// bar's measured height with `jouleTabBarClearance`, so its scroll views stop above the bar.
/// (An inset on the TabView itself does not reach the tabs' content on iOS 26.)
struct JouleTabBar: View {
    @Binding var selection: AppTab
    /// The bar's height above the home indicator, reported for the tabs' clearance.
    @Binding var height: CGFloat
    let onLogCharge: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(.dashboard)
            item(.batteryHealth)
            logButton
            item(.history)
            item(.garage)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .background {
            Color.joulePaper
                .overlay(alignment: .top) { Rectangle().fill(Color.jouleLine).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: AppTab) -> some View {
        let isOn = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isOn ? tab.selectedSymbol : tab.symbol)
                    .font(.system(size: 17, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.jouleVolt : Color.jouleMuted)
                    .frame(width: 56, height: 30)
                    .background {
                        if isOn {
                            Capsule().fill(Color.jouleInverse)
                        }
                    }
                Text(LocalizedStringKey(tab.shortTitle))
                    .font(.jouleText(11, relativeTo: .caption2).weight(isOn ? .bold : .medium))
                    .foregroundStyle(isOn ? Color.jouleInk : Color.jouleMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .animation(.snappy(duration: 0.2), value: isOn)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(tab.title)))
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }

    private var logButton: some View {
        Button(action: onLogCharge) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.jouleOnVolt)
                .frame(width: 56, height: 56)
                .background(Color.jouleVolt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.jouleOnVolt, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .offset(y: -4)
        .frame(maxWidth: .infinity)
        .keyboardShortcut("n", modifiers: .command)
        .accessibilityLabel("Log charge")
        .accessibilityHint("Opens the form to log a new charging session")
    }
}

extension EnvironmentValues {
    /// Height of the overlaid `JouleTabBar`, or 0 where there is none (Mac, sheets' own roots).
    @Entry var jouleTabBarHeight: CGFloat = 0
}

/// Reserves room for the overlaid tab bar at the bottom of a scroll view. It goes on the scroll
/// view itself: a safe-area inset applied further out (on the TabView, or on a tab's
/// NavigationStack) does not reach the scroll view's content inset on iOS 26.
private struct TabBarClearance: ViewModifier {
    @Environment(\.jouleTabBarHeight) private var height

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: height)
        }
    }
}

extension View {
    /// Apply to the scroll view (ScrollView, List, Form) of any screen shown inside a tab.
    func jouleTabBarClearance() -> some View {
        modifier(TabBarClearance())
    }
}
