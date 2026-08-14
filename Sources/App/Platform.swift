import Foundation

enum Platform {
    /// True when running on a Mac, whether via Mac Catalyst or "Designed for iPad" on Apple silicon.
    static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return ProcessInfo.processInfo.isiOSAppOnMac
        #endif
    }
}
