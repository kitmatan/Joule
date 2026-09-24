import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreText

// MARK: - Colour tokens
//
// The "instrument panel" palette: warm paper, near-black ink, one volt accent reserved for the
// live element on a screen (current month, current health, the primary action). AC is always blue
// and DC always orange, and the two also differ in lightness so they stay apart without colour.
// Every token resolves per trait, so the app theme's window override restyles all of it at once.

extension Color {
    /// Page background.
    static let joulePaper = Color(light: 0xF3F1EA, dark: 0x111214)
    /// Cards and rows that sit on the page.
    static let jouleSurface = Color(light: 0xFFFFFF, dark: 0x1B1C20)
    /// The selected segment of a pill picker: above the track in both themes.
    static let jouleRaised = Color(light: 0xFFFFFF, dark: 0x3A3C43)
    /// Recessed fills: segmented tracks, empty gauge cells, progress tracks.
    static let jouleSunken = Color(light: 0xE7E4DB, dark: 0x26272C)
    /// Hairlines and card borders.
    static let jouleLine = Color(light: 0xE1DDD2, dark: 0x2C2E33)

    /// Primary text and icons.
    static let jouleInk = Color(light: 0x15161A, dark: 0xF3F1EA)
    /// Secondary text.
    static let jouleInk2 = Color(light: 0x3D4048, dark: 0xC9CBD0)
    /// Captions and labels. Holds 4.5:1 on both paper and surface in either theme.
    static let jouleMuted = Color(light: 0x5E6169, dark: 0x9A9DA4)

    /// The accent. Only ever a fill — text on it is `jouleOnVolt`.
    static let jouleVolt = Color(light: 0xD6F35B, dark: 0xD6F35B)
    static let jouleOnVolt = Color(light: 0x15161A, dark: 0x15161A)

    /// The dark "instrument" card (battery health) in light mode; a raised olive-black in dark.
    static let jouleInverse = Color(light: 0x15161A, dark: 0x1F2218)
    static let jouleOnInverse = Color(light: 0xF3F1EA, dark: 0xF3F1EA)
    static let jouleOnInverseMuted = Color(light: 0xAEB0B5, dark: 0xAEB0B5)
    static let jouleInverseTrack = Color(light: 0x2A2C31, dark: 0x33372B)

    static let jouleAC = Color(light: 0x2B55C9, dark: 0x7C9BFF)
    static let jouleACSoft = Color(light: 0xE6ECFB, dark: 0x1E2748)
    static let jouleACOnSoft = Color(light: 0x2146AE, dark: 0xB4C6FF)

    static let jouleDC = Color(light: 0xEE8A4A, dark: 0xF29A5E)
    static let jouleDCSoft = Color(light: 0xFBE7D9, dark: 0x3A2518)
    static let jouleDCOnSoft = Color(light: 0xA63A0C, dark: 0xFFB585)

    /// Money that lands on the power bill later.
    static let jouleDeferred = Color(light: 0xA15C07, dark: 0xE5A04A)
    static let jouleDeferredSoft = Color(light: 0xFBF0DC, dark: 0x33260F)
    static let jouleDeferredOnSoft = Color(light: 0x6B4510, dark: 0xF2C987)

    /// Capacity lost, destructive actions.
    static let jouleDanger = Color(light: 0xB42318, dark: 0xFF8A7A)
    /// Money saved, healthy habits.
    static let joulePositive = Color(light: 0x3F6212, dark: 0xB7DB5A)
    static let joulePositiveSoft = Color(light: 0xEEF5D6, dark: 0x252C14)

    /// Externally measured service readings, kept visibly apart from Joule's own estimate.
    static let jouleReference = Color(light: 0x5B3FC4, dark: 0xB6A4FF)
    static let jouleReferenceSoft = Color(light: 0xEFEBFB, dark: 0x251F3D)

    fileprivate init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        self.init(red: Double((light >> 16) & 0xFF) / 255, green: Double((light >> 8) & 0xFF) / 255, blue: Double(light & 0xFF) / 255)
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

extension ChargingType {
    var jouleColor: Color { self == .dc ? .jouleDC : .jouleAC }
    var jouleSoft: Color { self == .dc ? .jouleDCSoft : .jouleACSoft }
    var jouleOnSoft: Color { self == .dc ? .jouleDCOnSoft : .jouleACOnSoft }
}

// MARK: - Type
//
// Bricolage Grotesque for figures and headings, Geist for text, Geist Mono for labels and
// tabular readouts. Each face is registered through UIAppFonts; `relativeTo` keeps every size on
// Dynamic Type. A face that fails to register degrades to the system font rather than to nothing.

enum JouleFontName {
    static let display = "BricolageGrotesque36pt-Bold"
    static let text = "Geist"
    static let mono = "Geist Mono"
}

extension Font {
    /// Figures and headings.
    static func jouleDisplay(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom(JouleFontName.display, size: size, relativeTo: style)
    }

    /// Running text. Weight modifiers pick the matching Geist face.
    static func jouleText(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(JouleFontName.text, size: size, relativeTo: style)
    }

    /// Labels and numeric readouts.
    static func jouleMono(_ size: CGFloat = 12, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom(JouleFontName.mono, size: size, relativeTo: style)
    }

    /// The app's stand-in for each system text style, at the same default sizes.
    static func joule(_ style: Font.TextStyle) -> Font {
        switch style {
        case .largeTitle: return .jouleDisplay(34, relativeTo: .largeTitle)
        case .title: return .jouleDisplay(28, relativeTo: .title)
        case .title2: return .jouleDisplay(22, relativeTo: .title2)
        case .title3: return .jouleText(20, relativeTo: .title3).weight(.semibold)
        case .headline: return .jouleText(17, relativeTo: .headline).weight(.semibold)
        case .body: return .jouleText(17, relativeTo: .body)
        case .callout: return .jouleText(16, relativeTo: .callout)
        case .subheadline: return .jouleText(15, relativeTo: .subheadline)
        case .footnote: return .jouleText(13, relativeTo: .footnote)
        case .caption: return .jouleText(12, relativeTo: .caption)
        case .caption2: return .jouleText(11, relativeTo: .caption2)
        @unknown default: return .jouleText(17, relativeTo: style)
        }
    }
}

// MARK: - UIKit chrome

#if canImport(UIKit)
enum JouleAppearance {
    /// Registers the bundled faces, then styles the UIKit-drawn chrome SwiftUI does not expose:
    /// navigation bar titles and the segmented controls behind `.pickerStyle(.segmented)`.
    /// Call once, before the first window.
    @MainActor
    static func configure() {
        registerBundledFonts()

        let ink = UIColor(Color.jouleInk)
        let nav = UINavigationBar.appearance()
        if let large = UIFont(name: JouleFontName.display, size: 34) {
            nav.largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large),
                .foregroundColor: ink
            ]
        }
        if let inline = UIFont(name: "Geist-SemiBold", size: 17) {
            nav.titleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline),
                .foregroundColor: ink
            ]
        }

        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = UIColor(Color.jouleRaised)
        segmented.backgroundColor = UIColor(Color.jouleSunken)
        if let face = UIFont(name: "Geist-Medium", size: 13) {
            let scaled = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: face)
            segmented.setTitleTextAttributes([.font: scaled, .foregroundColor: UIColor(Color.jouleInk2)], for: .normal)
            segmented.setTitleTextAttributes([.font: scaled, .foregroundColor: ink], for: .selected)
        }
    }

    /// Info.plist's UIAppFonts registers the faces too, but an incremental Xcode build can ship a
    /// stale processed Info.plist without it, and every custom font then silently falls back to
    /// the system face. Registering from the bundle does not depend on that. Each file is named
    /// after its PostScript name, so a face UIAppFonts already registered is skipped.
    private static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where UIFont(name: url.deletingPathExtension().lastPathComponent, size: 12) == nil {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
#endif
