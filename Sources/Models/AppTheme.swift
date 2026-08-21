import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// User-selectable appearance for the whole app.
///
/// `system` defers to the device's Light/Dark setting; the other two pin the app regardless of it.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    static let storageKey = "app_theme"

    /// Fallback used by every `@AppStorage("app_theme")` declaration.
    static let defaultTheme: AppTheme = .system

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    /// The scheme to force via `preferredColorScheme`. `nil` follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    #if canImport(UIKit)
    /// UIKit equivalent of `colorScheme`, used to restyle live windows.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Forces every open window to this theme.
    ///
    /// `preferredColorScheme` alone is not enough: under Mac Catalyst it restyles views presented
    /// *after* the change (a sheet, say) but leaves the already-rendered window untouched until
    /// relaunch, so switching themes appears to do nothing. Setting the window's override drives
    /// the whole hierarchy on every platform, and `.unspecified` hands control back to the system.
    @MainActor
    func applyToOpenWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
    #endif

    var footerDescription: String {
        switch self {
        case .system: return "Joule follows your device's Light/Dark appearance setting."
        case .light: return "Joule always uses the light appearance, even when your device is in Dark Mode."
        case .dark: return "Joule always uses the dark appearance, even when your device is in Light Mode."
        }
    }
}
