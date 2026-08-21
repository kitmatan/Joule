import XCTest
import SwiftUI
@testable import Joule

final class AppThemeTests: XCTestCase {

    func testColorSchemeMapping() {
        // `.system` must stay nil — that is what hands control back to the device setting.
        XCTAssertNil(AppTheme.system.colorScheme)
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
    }

    func testInterfaceStyleMatchesColorScheme() {
        // The window override is what actually restyles a live window (Catalyst ignores
        // preferredColorScheme on the already-rendered root), so it must not drift from the
        // SwiftUI mapping above.
        XCTAssertEqual(AppTheme.system.interfaceStyle, .unspecified)
        XCTAssertEqual(AppTheme.light.interfaceStyle, .light)
        XCTAssertEqual(AppTheme.dark.interfaceStyle, .dark)
    }

    func testRawValuesAreStableForAppStorage() {
        // @AppStorage persists the raw value; changing these strings would silently reset the
        // preference of anyone who already picked a theme.
        XCTAssertEqual(AppTheme.system.rawValue, "System")
        XCTAssertEqual(AppTheme.light.rawValue, "Light")
        XCTAssertEqual(AppTheme.dark.rawValue, "Dark")
        XCTAssertEqual(AppTheme.storageKey, "app_theme")
        XCTAssertEqual(AppTheme.defaultTheme, .system)
    }

    func testEveryCaseHasDistinctIconAndDescription() {
        XCTAssertEqual(AppTheme.allCases.count, 3)

        let icons = Set(AppTheme.allCases.map(\.iconName))
        XCTAssertEqual(icons.count, AppTheme.allCases.count)

        for theme in AppTheme.allCases {
            XCTAssertFalse(theme.iconName.isEmpty)
            XCTAssertFalse(theme.footerDescription.isEmpty)
            XCTAssertEqual(theme.displayName, theme.rawValue)
            XCTAssertEqual(theme.id, theme.rawValue)
            XCTAssertEqual(AppTheme(rawValue: theme.rawValue), theme)
        }
    }
}
